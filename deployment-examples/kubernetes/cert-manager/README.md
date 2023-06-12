# Issuing certificates to Kubernetes services using an external EJBCA EE

This is a simplified example of how to setup an EJBCA EE installation to issue certificates to services running in <https://microk8s.io/>
Kubernetes using the ACME protocol specified described in <https://tools.ietf.org/html/rfc8555>.

The scope of this example is to demonstrate that:

* EJBCA EE can be used to automatically provision TLS certificate to services (in the broader sense) running on Kubernetes.
* EJBCA EE's ACME Draft 12 implementation is compatible with <https://docs.cert-manager.io/>.
* ACME can be used internally in an organization for automation of certificate management without publishing internal DNS names to a public service.

## Background

Deployments (applications) in Kubernetes are by default only available from inside the cluster.
Using an Ingress (similar to a virtual host) can expose the Deployment to the outside world for consumption.
Using HTTPS for the Ingress will enable clients of the application to trust that they are using the genuine application and provide confidentiality.
For public facing services a HTTPS/TLS certificate from a publicly trusted CA is needed.
For services inside an organization it is usually both sufficient and necessary that the certificate are issued by an internal trusted CA.
This example covers the use-case where you need to use an internal trusted CA service.

`cert-manager` is a native Kubernetes certificate management controller. It can issue certificates for Ingresses using the ACME protocol.

PrimeKey's EJBCA EE is a high performance, secure, flexible and scalable enterprise grade PKI software that support the ACME protocol for certificate issuance.


## Demo base system installation

This example was setup on a Debian 9.6 net-installer image running in as a guest VM on KVM with IP `192.168.122.68`.

We will use ACME `http-01` validation during certificate issuance and hence each domain name needs to be resolvable from both the CA and the Kubernetes installation.
To avoid setting up a full DNS system, we add a DNS alias for the VM guest on the VM host and use this DNSName hereafter:
```
echo "192.168.122.68 testsystem.example.org" | sudo tee -a /etc/hosts
```

The EJBCA EE instance is running on the VM host and is reached at `192.168.122.1` from the the VM.

EJBCA is configured in the following way:
* The ACME protocol is enabled and the default alias uses an End Entity Profile called "certManager".
* The End Entity Profile "certManager" has 
  * Username: Auto-generated
  * Password: Required
  * Batch: Use
  * End Entity Email: Use, Not Required, Modifiable
  * Subject (Distinguished Name) CN: Required, Modifiable
  * Subject (Alternative Name) DNS Name: Required, Modifiable
  * Default Certificate Profile: "SERVER"
  * Available Certificate Profiles: "SERVER"
  * Default CA: "CA of your choice"
  * Available CAs: <same as previous selection>
  * Default Token: User Generated
  * Available Tokens: User Generated
* The "CA of your choice" has
  * Enforce unique DN: Unselected
* Also, download the PEM encoded CA certificate of the issuer that signed the EJBCA installations TLS certificate for later use.
* For this example "CA of your choice" is also the CA that issued the HTTPS certificate of the CA ACME service.


On Debian an installation of <https://microk8s.io/> v1.13.4 can look like the following: 
```
sudo apt-get install -y snapd
sudo snap install core
sudo snap install microk8s --classic
sudo snap alias microk8s.kubectl kubectl
kubectl get all,ingress,secret,no --all-namespaces
```

For this example we will enable a few basic addons:
```
microk8s.enable dns dashboard ingress
```

Optionally, you can enable direct access to the dashboard on `https://testsystem.example.org:30443/` with [kubernetes-dashboard-nodeport.yaml](kubernetes-dashboard-nodeport.yaml)
```
kubectl create -f kubernetes-dashboard-nodeport.yaml
```

Re-configure the default DNS servers used by the cluster to the host machine so `testsystem.example.org` will be resolvable when adding an Ingress later on with:
```
kubectl patch --namespace kube-system configmap kube-dns --patch '{"data":{"upstreamNameservers":"[\"192.168.122.1\"]"}}'
```

Verify that `testsystem.example.org` is resolvable from the Ingress controller.
```
kubectl get pod --namespace=default
```

```
NAME                                      READY   STATUS    RESTARTS   AGE
default-http-backend-855bc7bc45-sb5qt     1/1     Running   0          119s
nginx-ingress-microk8s-controller-d8dl4   1/1     Running   0          119s
```

```
kubectl exec nginx-ingress-microk8s-controller-d8dl4 -i -t -- bash -c 'ping -c 1 testsystem.example.org'
```


## Setting up cert-manager to use the external EJBCA EE's ACME service

Start by installing the vanilla `cert-manager`:
```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.7/deploy/manifests/cert-manager.yaml
```

Optional: Instead of accessing the ACME service running on the host by IP:port or DNS-name:port, we define a Service abstraction [service-pki-service.yaml](service-pki-service.yaml) so it can be reached by using `https://pki-service/ejbca/acme/directory`:
```
kubectl create -f service-pki-service.yaml
```

Note: It is important that the HTTPS server side certificate of the ACME service can be
validated against the ACME URL you use by having a matching Subject Alternative Name of type `IPAddress` or `DNSName`.
In this example the certificate must have `DNSName=external-ejbca`, but in an corporate environment your CA service most likely have a stable and resolvable
DNS name and they you should use this.

To allow any outbound traffic from the guest VM to the CA running on the VM host we change the firewall policy from DROP to ACCEPT in the guest:
```
sudo iptables -P FORWARD ACCEPT
```

When the server side TLS certificate of `https://pki-service/ejbca/acme/directory` isn't trusted by the Kubernetes installation, we need to configure `cert-manager` to trust the issuing CA of this certificate. The CA Certificate can imported as a Secret [secret-acme-tls-ca.yaml](secret-acme-tls-ca.yaml):
```
kubectl create -f secret-acme-tls-ca.yaml
```

`cert-manager` can then be reconfigured to trust this CA certificate for HTTPS connections used by the ACME protocol by referencing this Secret:
```
KUBE_EDITOR="nano" kubectl -n cert-manager edit deployment cert-manager
```
and add a mount of the CA certificate specified in `secret-acme-tls-ca.yaml`:
```
        ...
        volumeMounts:
        - name: volume-acme-tls-ca
          mountPath: "/etc/ssl/certs/"
          readOnly: true
      volumes:
        - name: volume-acme-tls-ca
          secret:
            secretName: secret-acme-tls-ca
```

Finally the ClusterIssuer [clusterissuer-ejbca-acme.yaml](clusterissuer-ejbca-acme.yaml) referencing the ACME service can be configured:
```
kubectl create -f clusterissuer-ejbca-acme.yaml
```

(A ClusterIssuer should according to <https://docs.cert-manager.io/en/latest/reference/clusterissuers.html> be able to issue certificate for all nodes in the cluster.)


## Requesting a certificate manually

As described earlier, the CA can resolve `testsystem.example.org` to the VM running `microk8s` so we will issue a TLS certificate for this domain.

An explicit declaration of issuance would look like [cert-testsystem-example-org.yaml](cert-testsystem-example-org.yaml) and can be requested with:
```
kubectl create -f cert-testsystem-example-org.yaml
```
and the progress can be followed by using `describe` on the resource. Note that the namespace of this certificate is different from the one `cert-manager` uses.


If everything works so far you should be able to see that an account was created by the ClusterIssuer:
```
kubectl describe clusterissuer clusterissuer-ejbca-acme
```

```
...
Status:
  Acme:
    Uri:  https://.../ejbca/acme/acct/fjb-...tUtQ
  Conditions:
    Last Transition Time:  ...
    Message:               The ACME account was registered with the ACME server
    Reason:                ACMEAccountRegistered
    Status:                True
    Type:                  Ready
```

and that the certificate has been issued:
```
kubectl describe certificate cert-testsystem-example-org
```

```
...
Status:
  Conditions:
    Last Transition Time:  ...
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               ...
```



In the EJBCA logs that registration of a new ACME account should also be visible:
```
... INFO  [...AcmeLoggingFilter] (...) GET https://pki-service/ejbca/acme/directory from ...
... INFO  [...AcmeLoggingFilter] (...) POST https://pki-service/ejbca/acme/newAccount from ...
... INFO  [...AcmeLoggingFilter] (...) POST https://pki-service/ejbca/acme/newOrder from ...
... INFO  [...AcmeLoggingFilter] (...) POST https://pki-service/ejbca/acme/acct/fjb-...tUtQ/orders/DKw6...yihM/finalize from ...
... INFO  [...Log4jDevice] (...) ...;CERT_CREATION;SUCCESS;CERTIFICATE;CORE;...
... INFO  [...AcmeLoggingFilter] (default task-1) GET https://pki-service/ejbca/acme/cert/d2bf...126d from ...
... INFO  [...AcmeLoggingFilter] (default task-1) GET https://pki-service/ejbca/acme/acct/fjb-...tUtQ/orders/DKw6...yihM from ...

```


## Use the ingress-shim to automatically expose the dashboard with TLS cert from EJBCA

By annotation an Ingress, we can now automatically create a TLS certificate from EJBCA to it. As a basic example the Kubernetes dashboard can now be exposed using an Ingress [kubernetes-dashboard-ingress.yaml](kubernetes-dashboard-ingress.yaml) with a TLS certificate issued by EJBCA.

```
kubectl create -f kubernetes-dashboard-ingress.yaml
```

In the Events log of the Ingress and referenced Certificate, the certificate creation operation is visible.
```
kubectl describe ingress --namespace=kube-system
kubectl describe certificate --namespace=kube-system cert-ingress-testsystem-example-org
```

```
...
Events:
  Type    Reason             Age   From                      Message
  ----    ------             ----  ----                      -------
  Normal  CREATE             5s    nginx-ingress-controller  Ingress kube-system/kubernetes-dashboard-ingress
  Normal  CreateCertificate  5s    cert-manager              Successfully created Certificate "cert-ingress-testsystem-example-org"
  Normal  UPDATE             4s    nginx-ingress-controller  Ingress kube-system/kubernetes-dashboard-ingress
...
Events:
  Type    Reason              Age   From          Message
  ----    ------              ----  ----          -------
  Normal  Generated           43s   cert-manager  Generated new private key
  Normal  GenerateSelfSigned  43s   cert-manager  Generated temporary self signed certificate
  Normal  OrderCreated        43s   cert-manager  Created Order resource "cert-ingress-testsystem-example-org-1477928639"
  Normal  OrderComplete       21s   cert-manager  Order "cert-ingress-testsystem-example-org-1477928639" completed successfully
  Normal  CertIssued          21s   cert-manager  Certificate issued successfully
```

Once the self-signed temporary certificate has been replaced, accessing `https://testsystem.example.org` will now expose the dashboard.
Clicking the "pad lock" icon in the location bar and viewing certificate details will display that the issuer is indeed the CA configured in EJBCA's ACME configuration.

### Clean up

The entire Kubernetes installation can be removed with:
```
sudo snap remove microk8s
```
