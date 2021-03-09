## Working with KUTTL

### About KUTTL

The KUbernetes Test TooL (KUTTL) is a toolkit that provides a declarative approach using YAML to test Kubernetes Operators. It provides a way to inject an operator (subject under test) during the TestSuite setup and allows tests to be standard YAML files. Test assertions are often partial YAML documents which assert the state defined is true. It is also possible to have KUTTL automate the setup of a cluster.

For more information on KUTTL, please go to check its website: https://kuttl.dev/.

### Combine KUTTL with KubeAssert

In KUTTL, test assert is written in YAML and can match specific objects by name as well as match any object that matches a defined state. If an object has a name set, then KUTTL will look specifically for that object to exist and verify its state matches what is defined in assert file. For example, if the file has:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
status:
  phase: Successful
```

Then KUTTL will wait for the `my-pod` pod in the test namespace to have `status.phase=Successful`.

However, it is too limited to make assertion like this. By default, it is hard to use KUTTL to assert things such as pod restarts count should be less than a value, or there should be no pod that keeps terminating, and so on. This is where KubeAssert comes into play!

Fortunately, start from v0.9.0, KUTTLE allows users to specify commands or scripts in assert file to assert status. It gives us the opportunity to combine KUTTL with KubeAssert to write more powerful assertions against Kubernetes resources.

### Writing Your First Test using KUTTL and KubeAssert

Let's revisit the "[Writing Your First Test](https://kuttl.dev/docs/kuttl-test-harness.html#writing-your-first-test)" on KUTTL website and see how it can be modified to use KubeAssert when you write assertions.

#### Create a Test Case

First, let's create the directory `tests/e2e` for our test suite and the sub-directory `example-test` for the test case:
```console
mkdir -p tests/e2e/example-test
```

Next, create the test step `00-install.yaml` in `tests/e2e/example-test/` to create the deployment `example-deployment`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

Then, create the test assert `tests/e2e/example-test/00-assert.yaml`
```yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- command: kubectl assert exist-enhanced deployment example-deployment -n $NAMESPACE --field-selector status.readyReplicas=3
```

Here we use TestAssert with a command using KubeAssert to assert the test step is completed if the `status.readyReplicas` of deployment `example-deployment` is 3. Please note the use of `$NAMESPACE`. It is provided by KUTTL to indicate which namespace KUTTL is running the test under.


#### Write a Second Test Step

In the second step, we increase the number of replicas on the deployment we created from 3 to 4. This is defined in `tests/e2e/example-test/01-scale.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
spec:
  replicas: 4
```

The assert for it in `tests/e2e/example-test/01-assert.yaml` using KubeAssert:
```yaml
apiVersion: kuttl.dev/v1beta1
kind: TestAssert
commands:
- command: kubectl assert exist-enhanced deployment example-deployment -n $NAMESPACE --field-selector status.readyReplicas=4
```

It is almost the same content as above, just the expected value of `status.readyReplicas` is changed to 4.
 
Run the test suite and validate if the test can pass:
```console
kubectl kuttl test --start-kind=true ./tests/e2e/
```

For more instructions on this sample test, please refer to the original [document](https://kuttl.dev/docs/kuttl-test-harness.html#writing-your-first-test) on KUTTL website. As you can see, to integrate KUTTL with KubeAssert is quite straightforward. The above test only demonstrates some basic capabilities of KubeAssert. Certainly you can define more advanced assertions using KubeAssert when you run KUTTL tests.
