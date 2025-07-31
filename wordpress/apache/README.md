# This is Custom Wordpress Apache Dockerfile

It's made to have flexibility to install themes and plugins, including select custom PHP, Apache, and WordPress versions.

## FAQ

- Why not use official WordPress image?

  - The official WordPress image is too opinionated and doesn't allow for custom PHP, Apache, and WordPress versions.

- Why including plugins and themes in the image?
  - This allow you to create stateless containers that can be easily deployed in Google Cloud Run or other serverless platforms.

## Notes

- If you download plugins from WordPress.org, usually it has a version number in the filename, e.g. `plugin-name-1.2.3.zip`. You can remove the version number to make it easier to update the plugin in the future, e.g. `plugin-name.zip`. ( This rules applies to themes as well. )
- This docker is smart enough to detect the plugin and theme, if you put the directory in the plugins it will automatically move to the wordpress plugins directory, and if it's archive `.zip` it will automatically extract the archive to the plugins directory.

## TODO

1. Include `imagemagick` and `ghostscript` for image processing.
2. Custom copy file for certain plugins on the fly for Stateless mode.
