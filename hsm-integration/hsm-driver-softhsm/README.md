![Keyfactor Community](../keyfactor_community_logo.png)

See the provided docker-compose.yml for an example of how to use a net-HSM (mocked by SoftHSMv2) with EJBCA:


```bash
docker-compose up --build
```

For Kubernetes/Openshift, the `docker-compose` example corresponds to:

```yaml
apiVersion: apps/v1
kind: Deployment
...
spec:
  template:
    spec:
      initContainers:
      - name: hsm-driver-init
        image: registry.primekey.com/primekey/hsm-driver-softhsm:0.4.20
        command: ['sh', '-c', 'cp --preserve --recursive /opt/primekey/p11proxy-client/* /mnt/']
        volumeMounts:
        - name: p11proxy-client
          mountPath: /mnt
      containers:
      - name: hsm-driver
        image: registry.primekey.com/primekey/hsm-driver-softhsm:0.4.20
        ...
        env:
        - name: SOFTHSM2_LOG_LEVEL
          value: INFO
        ...
      - name: application
        image: registry.primekey.com/primekey/ejbca-ee:7.10.0.1
        ...
        volumeMounts:
        - name: p11proxy-client
          mountPath: /opt/primekey/p11proxy-client
        ...
      volumes:
        - name: p11proxy-client
          emptyDir: {}
```