# Serenditree Stem

## About

This project provides the command-line interface and GitOps truth. 

Images are built using buildah. The steps for building and running an image are defined in files called `plot.sh`.
Folders containing a file called `plot.sh` contain everything that is needed to build and run .
```
> sc plots
ORDINAL  SERVICE            IMAGE                     TAG     PATH
1        soil-java-base     serenditree/java-base     latest  /home/tanwald/Development/Serenditree/stem/plots/soil/java/plot-java.sh:base:0
2        soil-java-builder  serenditree/java-builder  latest  /home/tanwald/Development/Serenditree/stem/plots/soil/java/plot-java.sh:builder:1
3        soil-node-base     serenditree/node-base     latest  /home/tanwald/Development/Serenditree/stem/plots/soil/node/plot-node.sh:base:0
4        soil-node-builder  serenditree/node-builder  latest  /home/tanwald/Development/Serenditree/stem/plots/soil/node/plot-node.sh:builder:1
5        soil-nginx         serenditree/nginx         latest  /home/tanwald/Development/Serenditree/stem/plots/soil/nginx/plot.sh
6        soil-buildah       serenditree/buildah       latest  /home/tanwald/Development/Serenditree/stem/plots/soil/buildah/plot.sh
7        root-user          serenditree/root-user     latest  /home/tanwald/Development/Serenditree/stem/plots/root/user/plot.sh
8        root-seed          serenditree/root-seed     latest  /home/tanwald/Development/Serenditree/stem/plots/root/seed/plot.sh
9        root-map           serenditree/root-map      latest  /home/tanwald/Development/Serenditree/stem/plots/root/map/plot.sh
10       root-wind          serenditree/root-wind     latest  /home/tanwald/Development/Serenditree/stem/plots/root/wind/plot.sh
11       branch-user        serenditree/branch-user   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:user:user:0
12       branch-seed        serenditree/branch-seed   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:seed:seed:1
13       branch-poll        serenditree/branch-poll   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:poll:user:2
14       leaf               serenditree/leaf          latest  /home/tanwald/Development/Serenditree/stem/plots/leaf/plot.sh
```

## Structure

- **charts:**
  Helm charts organized for the "app of apps" pattern.
- **plots/branch**:
  Definition of all Java services.

- **plots/leaf**:
  Definition of the Angular frontend service.

- **plots/root**:
  Standalone backend/middleware services including tile-server, kafka, user-database and seed/garden-database.

- **plots/soil**:
  Base images.

- **rc**:
  Cluster resources and templates.

- **src**:
  Sub-scripts for the command-line interface.

The file `cli-template.sh` is processed by argbash which creates `cli.sh`, the entrypoint for the command-line interface
that processes command-line arguments and calls the functions of dedicated script-files.

```
Serenditree CLI
Usage:  sc [-a|--all] [--compose] [--delete] [-D|--dryrun] [-E|--expose] [-h|--help] [--init] [--insert] [--integration] [-k|--kubernetes] [-l|--local] [--open] [-o|--openshift] [-P|--prod] [--reset] [--setup] [-T|--test] [--upgrade] [-v|--verbose] [-w|--watch] [-y|--yes] [--issuer <arg>] [--resume <arg>] [--] <command> ... 

	<command>:          Command to execute. Please type sc <help> for a list of commands!
	... :               Other arguments passed to command.
	-a, --all:          All...
	--compose:          Run or build for podman compose.
	--delete:           Deletion flag.
	-D, --dryrun:       Activates dryrun mode.
	-E, --expose:       Exposes database ports on local pods.
	-h, --help:         Command help. Please type sc <help> for a list of commands!
	--init:             Initialization flag.
	--insert:           Inserts a new plot.
	--integration:      Run for integration testing.
	-k, --kubernetes:   Use vanilla kubernetes.
	-l, --local:        Target local cluster.
	--open:             Open plots.
	-o, --openshift:    Use openshift.
	-P, --prod:         Sets the target stage to prod. (default is dev)
	--reset:            Reset flag.
	--setup:            Setup flag.
	-T, --test:         Sets the target stage to test. (default is dev)
	--upgrade:          Upgrade flag.
	-v, --verbose:      Verbose flag.
	-w, --watch:        Watch supported commands.
	-y, --yes:          Assumes yes on prompts.
	--issuer:           Set let's encrypt issuer to prod or staging. (default: 'prod')
	--resume:           Resume plots from the given plot. (default: '.*')

	Local commands:
	up [svc]:           Starts a local development stack or a single container. [--expose] [--watch] [--compose] [--integration]
	down [svc]:         Stops local stack or single containers. [--compose] [--integration] Stop cluster too: [--all]

	build [svc]:        Builds all or individual images.
	completion:         Adds bash-completion script to /etc/bash_completion.d/. [--all]
	compose [--] <cmd>: Run podman compose commands.
	config:             Prints cli and java config.
	context|ctx [id]:   Switch or display contexts.
	database|db <db>:   Open local database console. {user|maria|seed|mongo}
	deploy [svc]:       Deploys all or individual services to the local stack.
	env:                Prints global environment variables based on context.
	git [--] <cmd>:     Execute arbitrary git commands.
	health:             Runs health-checks on services. [--watch]
	loc:                Prints lines of code.
	login <reg>:        Login to configured registries.
	logs|log [svc]:     Prints logs of all or individual services on the local pod.
	plots:              Prints or inserts/deletes plots. [--all] [--open] [--insert|--delete]
	ps:                 Lists locally running serenditree containers.
	push [svc]:         Push all or individual images.
	registry:           Inspect images in remote registries. [--verbose]
	release:            Updates the parent git repository and pushes new commits.
	reset:              Removes all local images created by this cli.
	restore:            Restores local databases from remote data.
	status:             Prints status information and checks prerequisites.
	update [comp]:      Update components.

	Cluster commands:
	up [comp]:          Cluster start/setup. [--init|--setup|--upgrade] [--resume] [--dashboard]
	down:               Cluster stop/deletion. [--reset|--delete]

	backup:             Setup backup cronjobs or run backups from cronjobs. [--setup]
	certificate|cert:   Prints certificate information.
	clean:              Deletes dispensable resources.
	dashboard:          Launches the clusters dashboard.
	database|db <db>:   Open database console. {user|maria|seed|mongo}
	deploy:             Deploys new images.
	expose:             Port-forward operational services. [--reset|--delete]
	login:              Login to OpenShift and its internal registry.
	logs <svc>:         Prints logs of the given pod(s).
	registry [img]:     Inspects the OpenShift image registry.
	resources|rc [csv]: Prints resource allocations. Optionally in CSV.
	restore:            Restore databases.
	status:             Prints cluster status information.
	tekton|tkn [svc]:   Triggers tekton runs for all or individual services.

Please type 'sc <command> --help' for details about a certain command!
```
