## Writing Assertion

The out of box assertions provided by Kube Assert can support most scenarios in your day to day work. However, it is also possible that these assertions can not fullfil your requirement when you have some advanced cases.

Kube Assert supports custom assertion, where you can write your own assertion, then have Kube Assert load and execute it.

As an example, let's write an assertion to verify if your `kubeconfig` includes a cluster where the cluster name is specified as an argument when run the assertion from the command line.

### Create a Shell Script File

Let's create a shell script file called `custom-assertions.sh` and put it into `$HOME/.kube-assert` directory. This is where Kube Assert loads the custom assertions. Each time when Kube Assert is started, it will find all `.sh` files in this directory and load them as custom assertions.

The file can include multiple assertions. Each assertion is implemented as a shell function. In our case, we only have one assertion, which is the function `cluster` and right now the function body is empty:
```shell
#!/bin/bash

function cluster {
  :
}
```

To test the assertion, run `kubectl assert` and specify the funtion name `cluster` as the assertion name:
```console
kubectl assert cluster
ASSERT PASS
```

You see the assertion is passed since we have nothing added yet.

### Implement the Assertion

In order to implement an assertion, usually you will get a few things to do:

* **Validate input arguments**. In our case, it is the cluster name that will be input by user from the command line. If the validation is failed, you can call `logger::error` to print error message and exit the assertion with a non-zero code.
* **Print assertion message**. This will print a message, by calling `logger::assert`, to tell people what you are going to assert.
* **Run some kubectl commands**. This will query the cluster using `kubectl`.
* **Validate results**. By parsing the results returned from `kubectl`, either fail the assertion or let it pass. If the validation is failed, you can call `logger::fail` to print failure message. Otherwise, you can simply do nothing or call `logger::info` to print some normal logs to give user a bit more background on what is going on.

Here is our logic added to the `cluster` function:
```shell
#!/bin/bash

function cluster {
  # Validate input arguments
  [[ -z $1 ]] && logger::error "You must specify a cluster name." && exit 1
  # Print assertion message
  logger::assert "Cluster with name $1 should be included in kubeconfig."
  # Run some kubectl commands
  kubectl config get-clusters
  # Validate results
  if cat $HOME/.kube-assert/result.txt | grep -q ^$1$; then
    # Print normal logs
    logger::info "Found $1 in kubeconfig."
  else
    # Print failure message
    logger::fail "$1 not found."
  fi
}
```

You may notice that to validate the results, we actually look for a file called `result.txt` in `$HOME/.kube-assert/` directory. Our outputs returned by `kubectl` are all dumped into this file.

Now let's try the assertion without specifying a cluser name. It will show an error message to indicate the input argument is missing.
```console
kubectl assert cluster
ERROR  You must specify a cluster name.
```

Specify a cluster name that does not exist. It will fail the assertion with the reason printed to the console.
```console
kubectl assert cluster kind
ASSERT Cluster with name kind should be included in kubeconfig.
ASSERT FAIL kind not found.
```

Specify a cluster name that does exist. This will pass the assertion.
```console
kubectl assert cluster kind-foo
ASSERT Cluster with name kind-foo should be included in kubeconfig.
INFO   Found kind-foo in kubeconfig.
ASSERT PASS
```

If something goes wrong when you run the assertion, you may want to see what `kubectl` commands the assertion run and what the actual results they return for troubleshooting purpose, just enable the verbose logs using `-v` when you run the assertion.
```console
kubectl assert cluster kind-foo -v
ASSERT Cluster with name kind-foo should be included in kubeconfig.
INFO   kubectl config get-clusters
NAME
kind-foo
kind-bar
INFO   Found kind-foo in kubeconfig.
ASSERT PASS
```

### Add Comment to the Assertion

So far we have implemented our custom assertion. But there is one more thing left. To make the custom assertion visible in the supported assertion list when you run Kube Assert with `-h/--help` option or without any option, you need to add one special comment ahead of the assertion function. 

Also, when you run `kubectl assert <assertion>` with `-h/--help` option to print the help information for your assertion, it requires you to prepare the help information beforehand. This is also defined in the comment.

The comment should start with `##` and end with `##`, inside which there are a few fields where the field names are all started with `@`. Below is a template with detailed explanation for each field:
```shell
##
# @Name: <Input your single-line assertion name here>
# @Description: <Input your single-line assertion description here>
# @Usage: <Input your single-line assertion usage information here>
# @Options:
#   <Input help information for all your options started from here>
#   <It supports multiple lines>
# @Examples:
#   <Input detailed information for all examples started from here>
#   <It supports multiple lines>
##
```

For `Options` field, there are a few pre-defined variables which can be used. If your assertion supports some pre-defined options, you can simply put the corresponding variables in `Options` field as placeholders. They will be expanded to the actual contents when Kube Assert prints the help information.
* `${GLOBAL_OPTIONS}`: This variable represents the global options that should be applied to all assertions, e.g. `-h/--help` to print the help information.
* `${SELECT_OPTIONS}`: This variable represents the options used to filter on resources in cluster, e.g. `-l/--selector` to filter by labels, `-n/--namespace` to limit to a specific namespace.
* `${OP_VAL_OPTIONS}`: This variable represents the comparison operators, e.g. `-eq`, `-lt`, `-gt`, `-ge`, `-le`.

By using these variables, it also unifies the definitions for all these options across the assertions, including both the out-of-the-box ones and custom ones.

Here are the comment for our `cluster` assertion:
```shell
##
# @Name: cluster
# @Description: Assert specified cluster included in kubeconfig
# @Usage: kubectl assert cluster (NAME) [options]
# @Options:
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # To assert a cluster is included in kubeconfig
#   kubectl assert cluster kind-foo
##
function cluster {
  ...
}
```

To validate it, run below command to see if our assertion is included in the supported assertion list:
```console
kubectl assert --help
```

If all goes as expected, you will see `cluster` appeared in the list. Run below command to print the help information for our assertion:
```console
kubectl assert cluster --help
```

You will see below output which is exactly what we define in the comment as above:
```console
Assert cluster with specified name included in kubeconfig file

Usage: kubectl assert cluster (NAME) [options]

Options:
  -h, --help: Print the help information.
  -v, --verbose: Enable the verbose log.
  -V, --version: Print the version information.
```

### Put All Things Together

To put all things together, the final version of our `cluster` assertion can be found as below:
```shell
#!/bin/bash

##
# @Name: cluster
# @Description: Assert specified cluster included in kubeconfig
# @Usage: kubectl assert cluster (NAME) [options]
# @Options:
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # To assert a cluster is included in kubeconfig
#   kubectl assert cluster kind-foo
##
function cluster {
  # Validate input arguments
  [[ -z $1 ]] && logger::error "You must specify a cluster name." && exit 1
  # Print assertion message
  logger::assert "Cluster with name $1 should be included in kubeconfig."
  # Run some kubectl commands
  kubectl config get-clusters
  # Validate results
  if cat $HOME/.kube-assert/result.txt | grep -q ^$1$; then
    # Print normal logs
    logger::info "Found $1 in kubeconfig."
  else
    # Print failure message
    logger::fail "$1 not found."
  fi
}
```
