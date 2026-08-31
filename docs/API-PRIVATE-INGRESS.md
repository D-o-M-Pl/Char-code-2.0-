# API Private Ingress

Production API sets `publicNetworkAccess = Disabled` and is reachable through an App Service Private Endpoint in `privatelink.azurewebsites.net`.

Traffic model:

```text
Internet -> Front Door/WAF -> Web -> VNet Integration -> API Private Endpoint
```

The API default public App Service endpoint must not accept Internet traffic. Web/BFF is the public application boundary.
