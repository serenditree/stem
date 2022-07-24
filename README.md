# Serenditree Stem

## About

This project provides the command-line interface and GitOps truth. 

Images are built using buildah. The steps for building an image are defined in files called `plot.sh`. Folders
containing a file called `plot.sh` contain everything that is needed to build, run and deploy an image. Images that will
become services also contain an rc-folder, containing all cluster resources that are needed to run the service.

## Structure

- **plots/branch**:
  Definition of all Java services.

- **plots/leaf**:
  Definition of the Angular frontend service.

- **plots/root**:
  Standalone backend/middleware services including tile-server, kafka, user-database and seed/garden-database.

- **plots/soil**:
  Base images.

- **rc**:
  Cross-cutting cluster resources.

- **src**:
  Sub-scripts for the command-line interface.

The file `cli-template.sh` is processed by argbash which creates `cli.sh`, the entrypoint for the command-line interface
that processes command-line arguments and calls the functions of dedicated script-files.
