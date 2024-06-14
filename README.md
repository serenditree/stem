# Serenditree Stem

## About

This project provides the command-line interface and GitOps truth. 

Images are built using buildah. The steps for building an image and deployment routines are defined in files called
`plot.sh`. Folders containing a file called `plot.sh` contain everything that is needed to build, run and deploy an
image.

```
> sc plots
0        terra-base         -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/plot.sh
1        terra-cilium       -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/cilium/plot.sh
2        terra-argocd       -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/argocd/plot.sh
3        terra-cache        -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/cache/plot.sh
4        terra-ingress      -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/ingress/plot.sh
5        terra-tekton       -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/tekton/plot.sh
6        terra-prometheus   -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/prometheus/plot.sh
7        terra-https        -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/https/plot.sh
8        terra-issuer       -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/issuer/plot.sh
9        terra-strimzi      -                         -       /home/tanwald/Development/Serenditree/stem/plots/terra/charts/strimzi/plot.sh
10       soil-java-base     serenditree/java-base     latest  /home/tanwald/Development/Serenditree/stem/plots/soil/java/plot-java.sh:base:0
11       soil-java-builder  serenditree/java-builder  latest  /home/tanwald/Development/Serenditree/stem/plots/soil/java/plot-java.sh:builder:1
12       soil-node-base     serenditree/node-base     latest  /home/tanwald/Development/Serenditree/stem/plots/soil/node/plot-node.sh:base:0
13       soil-node-builder  serenditree/node-builder  latest  /home/tanwald/Development/Serenditree/stem/plots/soil/node/plot-node.sh:builder:1
14       soil-buildah       serenditree/buildah       latest  /home/tanwald/Development/Serenditree/stem/plots/soil/buildah/plot.sh
15       root-user          serenditree/root-user     latest  /home/tanwald/Development/Serenditree/stem/plots/root/user/plot.sh
16       root-seed          serenditree/root-seed     latest  /home/tanwald/Development/Serenditree/stem/plots/root/seed/plot.sh
17       root-map           serenditree/root-map      latest  /home/tanwald/Development/Serenditree/stem/plots/root/map/plot.sh
18       root-wind          serenditree/root-wind     latest  /home/tanwald/Development/Serenditree/stem/plots/root/wind/plot.sh
19       root-breeze        serenditree/root-breeze   latest  /home/tanwald/Development/Serenditree/stem/plots/root/breeze/plot.sh
20       branch-user        serenditree/branch-user   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:user:user:0
21       branch-seed        serenditree/branch-seed   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:seed:seed:1
22       branch-poll        serenditree/branch-poll   latest  /home/tanwald/Development/Serenditree/stem/plots/branch/plot-branch.sh:poll:user:2
23       leaf               serenditree/leaf          latest  /home/tanwald/Development/Serenditree/stem/plots/leaf/plot.sh
```

## Structure

- **plots/branch**:
  Definition of all Java services.

- **plots/leaf**:
  Definition of the Angular frontend service.

- **plots/root**:
  Standalone backend/middleware services including tile-server, kafka, user-database and seed/garden-database.

- **plots/soil**:
  Base images.

- **plots/terra**:
  Infrastructure as code and local "cluster" setup.

- **rc**:
  Cross-cutting cluster resources.

- **src**:
  Sub-scripts for the command-line interface.

The file `cli-template.sh` is processed by argbash which creates `cli.sh`, the entrypoint for the command-line interface
that processes command-line arguments and calls the functions of dedicated script-files.

```
> sc help
Usage:  sc [-T|--test] [-P|--prod] [-D|--dryrun] [-v|--verbose] [-a|--all] [-y|--assume-yes] [-E|--expose] [--open] 
[-w|--watch] [--init] [--setup] [--upgrade] [--reset] [--delete] [--imperative] [--resume <arg>] [--issuer <arg>] 
[--compose] [--integration] [-k|--kubernetes] [-o|--openshift] [-l|--local] [--dashboard] [-h|--help] [--] <command> ... 

	<command>:          Command to execute. Please type sc <help> for a list of commands!
	... :               Other arguments passed to command.
	-T, --test:         Sets the target stage to test. (default is dev)
	-P, --prod:         Sets the target stage to prod. (default is dev)
	-D, --dryrun:       Activates dryrun mode.
	-v, --verbose:      Verbose flag.
	-a, --all:          All...
	-y, --assume-yes:   Assumes yes on prompts.
	-E, --expose:       Exposes database ports on local pods.
	--open:             Open plots.
	-w, --watch:        Watch supported commands.
	--init:             Initialization flag.
	--setup:            Setup flag.
	--upgrade:          Upgrade flag.
	--reset:            Reset flag.
	--delete:           Deletion flag.
	--imperative:       Imperative flag.
	--resume:           Resume plots from the given ordinal. (default: '0')
	--issuer:           Set let's encrypt issuer to prod or staging. (default: 'prod')
	--compose:          Run or build for podman-compose.
	--integration:      Run for integration testing.
	-k, --kubernetes:   Use vanilla kubernetes.
	-o, --openshift:    Use openshift.
	-l, --local:        Target local cluster.
	--dashboard:        Open dashboard.
	-h, --help:         Command help. Please type sc <help> for a list of commands!

	Local commands:
	up [svc]:           Starts a local development stack or a single container. [--expose] [--watch] [--compose] [--integration]
	down [svc]:         Stops local stack or single containers. [--compose] [--integration] Stop cluster too: [--all]

	build [svc]:        Builds all or individual images.
	completion:         Adds bash-completion script to /etc/bash_completion.d/. [--all]
	compose [--] <cmd>: Run podman-compose commands.
	context|ctx [id]:   Switch or display contexts.
	database|db <db>:   Open local database console. {user|maria|seed|mongo}
	deploy [svc]:       Deploys all or individual services to the local stack.
	env:                Prints global environment variables based on context.
	expose:             Port-forward operational services. [--reset|--delete]
	git [--] <cmd>:     Execute arbitrary git commands.
	health|hc:          Runs health-checks on services. [--watch]
	loc:                Prints lines of code.
	login <reg>:        Login to configured registries.
	logs|log [svc]:     Prints logs of all or individual services on the local pod.
	plots:              Prints all available plots. [--open]
	ps:                 Lists locally running serenditree containers.
	push [svc]:         Push all or individual images.
	registry:           Inspect images in remote registries. [--verbose]
	release:            Updates the parent git repository and pushes new commits.
	reset:              Removes all local images created by this cli.
	status:             Prints status information and checks prerequisites.
	update [comp]:      Update components.

	Cluster commands:
	up [comp]:          Cluster start/setup. [--init|--setup|--upgrade] [--imperative] [--dashboard]
	down:               Cluster stop/deletion. [--reset|--delete]

	clean:              Deletes dispensable resources.
	dashboard:          Launches the clusters dashboard.
	database|db <db>:   Open database console. {user|maria|seed|mongo}
	deploy:             Deploys new images.
	login:              Login to OpenShift and its internal registry.
	logs <svc>:         Prints logs of the given pod(s).
	patch <arg>:        Applies patches to the current cluster.
	registry [img]:     Inspects the OpenShift image registry.
	resources|rc:       Lists project resources.
	restore:            Restore databases.
	certificate|cert:   Prints certificate information.
	tekton|tkn [svc]:   Triggers tekton runs for all or individual services.

Please type 'sc <command> --help' for details about a certain command!
```
