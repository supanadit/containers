# This is Custom Wordpress Apache Dockerfile

It's made to have flexibility to install themes and plugins, including select custom PHP, Apache, and WordPress versions.

## FAQ

- Why not use official WordPress image?

  - The official WordPress image is too opinionated and doesn't allow for custom PHP, Apache, and WordPress versions.

- Why including plugins and themes in the image?
  - This allow you to create stateless containers that can be easily deployed in Google Cloud Run or other serverless platforms.
