## Assertions

Below is a list of all available assertions that are supported by Kube Assert out of the box:

| Assertions                                                | Description
|:----------------------------------------------------------|:-----------
| [exist](assertions/exist.md)                              | Assert resource should exist.
| [not-exist](assertions/not-exist.md)                             | Assert resource should not exist.
| [exist-enhanced](assertions/exist-enhanced.md)            | Assert resource should exist using enhanced field selector.
| [not-exist-enhanced](assertions/not-exist-enhanced.md)    | Assert resource should not exist using enhanced field selector.
| [num](assertions/num.md)                                  | Assert the number of resource should match specified criteria.
| [pod-ready](assertions/pod-ready.md)                      | Assert pod should be ready.
| [pod-not-terminating](assertions/pod-not-terminating.md)  | Assert pod should not keep terminating.
| [pod-restarts](assertions/pod-restarts.md)                | Assert pod restarts should match specified criteria.
| [apiservice-available](assertions/apiservice-available.md)| Assert apiservice should be available.

To learn what each assertion is supposed to do and how to use it, please check the details for each assertion by clicking the assertion name in the above table.
