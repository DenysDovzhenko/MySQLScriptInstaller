#!/bin/bash

yellowColor='\033[1;33m'
redColor='\033[0;31m'
noColor='\033[0m'

destinationDir="/usr/local"
baseDir="/usr/local/mysql"
dataDir="/usr/local/mysql/data"
mysqlLinksDir="/usr/local/bin"

main() {
    case "$1" in
        "-help") 
            scriptHelp
            ;;

        "-install") 
            checkRoot
            [[ -f "$2" ]] && [[ "$(file -b --mime-type "$2")" = "application/x-xz" ]] && installing "$@" \
            || { echo -e "MySQL install: invalid file or path to tar.xz file ${redColor}'$2'${noColor}" \
                    "Try ${yellowColor}-help${noColor} for more information"; exit 2; }
            ;;

        "-uninstall") 
            checkRoot
            uninstalling "$@"
            exit 0
            ;;

        *) 
            echo -e "MySQL install: invalid option -- ${redColor}'$1'${noColor}\n" \
                 "Try ${yellowColor}-help${noColor} for more information"
            exit 2
            ;;
    esac
}

checkRoot() { [[ -z "$SUDO_USER" ]] && echo "This script must be run with sudo." && exit 1 ; }

installing() {
    mysqlArchive=$2
    tarName=$(basename $mysqlArchive .tar.xz)

    defaultRootPassword="11111111"

    echo -e "${redColor}Enter future MySQL user name:${noColor}" ; read user
    while [[ ${#user} -gt 32 ]]
    do
        echo -e "Username ${redColor}cannot${noColor} be greater than 32. Try again." ; read user
    done
    echo -e "${redColor}Enter password:${noColor}" ; read -s password

    echo -e "${yellowColor}Checking for dependencies${noColor}" ; pacman -S --needed libaio tar

    echo -e "${yellowColor}Adding user to mysql group${noColor}"
    groupadd mysql ; useradd -r -g mysql -s /bin/false mysql

    echo -e "${yellowColor}Unpacking your mysql file${noColor}" 
    tar xvf $mysqlArchive -C "$destinationDir/" && mv "$destinationDir"/"$tarName" "$baseDir"

    echo -e "${yellowColor}Adding links to mysql executionals to PATH${noColor}"

    for file in "$baseDir"/bin/*
    do
        [[ -x "$file" ]] && ln -s "$file" "$mysqlLinksDir/$(basename "$file")"
    done

    echo -e "${yellowColor}Setting owner of MySQL group${noColor}"
    mkdir $dataDir
    chown mysql:mysql $dataDir ; chmod 750 $dataDir

    echo -e "${yellowColor}Initializing mysqld${noColor}"
    mysqld --initialize-insecure --user=mysql --basedir="$baseDir" --datadir="$dataDir"

    echo -e "${yellowColor}Starting MySQL server${noColor}" ; mysqld --user=mysql &

    while !(mysqladmin ping)
    do
        sleep 3 ; echo -e "${yellowColor}Waiting for MySQL${noColor}"
    done

    echo -e "${yellowColor}Adding new user for MySQL server${noColor}"
    mysql -u root -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password'; \
                     GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO '$user'@'localhost'; \
                     FLUSH PRIVILEGES;"

    echo -e "${yellowColor}Changing root user password${noColor}"

    mysql -h "localhost" -u "root" --skip-password -Bse "ALTER USER 'root'@'localhost' IDENTIFIED BY '$defaultRootPassword';"

    exit 0
}

uninstalling() {
    mysqlBinFiles=/usr/local/mysql/bin

    mysqladmin shutdown -p

    for link in "$mysqlLinksDir"/* 
    do
        target="$(readlink -f "$link")"
        pathToExec="$(basename "$target")"

        [[ -e "$mysqlBinFiles/$pathToExec" ]] && rm $link
    done

    rm -rf /usr/local/mysql

    exit 0
}

scriptHelp() {
printf \
"${yellowColor}$0${noColor} script
This script installs MySQL in the /usr/local/ directory using the tar.xz archive from the Oracle website.
Immediately after installation, the server is launched and a new user is created with the password entered during the script execution.
The default password for the root user is set to 11111111.
Since the installation is performed without a package manager, the script offers to use the uninstall option to remove MySQL.\n
Usage: ${yellowColor}$0 [-help | -install <tar.xz_file> | -uninstall]${noColor}
\nOptions:
  ${yellowColor}-help${noColor}           Display this help message.
  ${yellowColor}-install <file>${noColor} Install MySQL using the specified tar.xz file.
  ${yellowColor}-uninstall${noColor}      Uninstall MySQL and remove associated links.
\nExample:
  ${yellowColor}./script.sh -install mysql-8.0.23-linux-glibc2.12-x86_64.tar.xz${noColor}\n"
}

main "$@"; exit
