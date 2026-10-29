-- mariadbmon needs global privileges on the server it monitors.
GRANT ALL PRIVILEGES ON *.* TO 'maxscale'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
