# Traefik Conditional JSON Metadata Plugin

A Traefik middleware plugin that conditionally adds JSON metadata to responses based on query parameters.

## Features

- ✅ Checks for configurable query parameters (default: `?include=meta`)
- ✅ Merges JSON metadata into existing response bodies
- ✅ Preserves original response structure and data
- ✅ Only processes JSON responses (based on Content-Type)
- ✅ Configurable metadata content
- ✅ Fully tested with unit tests

## Quick Start

When a request includes `?include=meta`, the plugin transforms:

**Original Response:**
```json
{
  "data": "translation result",
  "status": "success"
}
```

**Modified Response:**
```json
{
  "data": "translation result",
  "status": "success",
  "meta": {
    "route_name": "v2-translate"
  }
}
```

## Installation

### From Plugin Catalog (Recommended)

Add to your Traefik static configuration:

```yaml
# traefik.yml
experimental:
  plugins:
    conditional-meta:
      moduleName: "github.com/carlos/traefik-conditional-meta-plugin"
      version: "v0.1.0"
```

### Local Development

```yaml
# traefik.yml
experimental:
  localPlugins:
    conditional-meta:
      moduleName: "github.com/carlos/traefik-conditional-meta-plugin"
```

Place the plugin in `./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin/`

## Usage

### Basic Configuration

```yaml
# dynamic.yml
http:
  routers:
    api-router:
      rule: "Host(`api.example.com`)"
      service: api-service
      middlewares:
        - conditional-meta

  middlewares:
    conditional-meta:
      plugin:
        conditional-meta: {}  # Uses default settings

  services:
    api-service:
      loadBalancer:
        servers:
          - url: "http://backend:8080"
```

### Custom Configuration

```yaml
http:
  middlewares:
    conditional-meta:
      plugin:
        conditional-meta:
          queryParam: "format"
          queryValue: "extended"
          metaData:
            meta:
              route_name: "custom-route"
              version: "1.2.3"
            context:
              environment: "production"
```

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `queryParam` | string | `"include"` | The query parameter name to check |
| `queryValue` | string | `"meta"` | The value to match for the query parameter |
| `metaData` | object | `{"meta":{"route_name":"v2-translate"}}` | The JSON object to merge into responses |

## Examples

### Docker Compose

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    command:
      - --experimental.plugins.conditional-meta.moduleName=github.com/carlos/traefik-conditional-meta-plugin
      - --experimental.plugins.conditional-meta.version=v0.1.0
    labels:
      - "traefik.http.middlewares.conditional-meta.plugin.conditional-meta.metaData.meta.route_name=v2-translate"
```

### Kubernetes

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: conditional-meta
spec:
  plugin:
    conditional-meta:
      queryParam: "include"
      queryValue: "meta"
      metaData:
        meta:
          route_name: "v2-translate"
```

## Testing

Run the unit tests:

```bash
go test -v
```

Test locally with curl:

```bash
# Without metadata
curl "http://localhost/api/endpoint"

# With metadata
curl "http://localhost/api/endpoint?include=meta"
```

## Development

### Running Tests

```bash
go test -v ./...
```

### Building Locally

```bash
# For local development
mkdir -p ./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin
cp *.go ./plugins-local/src/github.com/carlos/traefik-conditional-meta-plugin/
```

### Publishing

1. Create a GitHub repository
2. Add the `traefik-plugin` topic
3. Tag a release: `git tag v0.1.0 && git push --tags`
4. The Plugin Catalog will automatically discover it within 30 minutes

## How It Works

1. **Request Interception**: Checks if the query parameter matches the configured value
2. **Response Buffering**: If metadata is needed, intercepts and buffers the response
3. **JSON Processing**: Parses JSON responses and merges the metadata
4. **Pass-through**: Non-JSON responses or requests without the query parameter pass through unchanged

## Troubleshooting

### Plugin Not Loading

- Check Traefik logs for compilation errors
- Ensure `go.mod` is valid
- Verify the plugin directory structure

### Metadata Not Added

- Confirm query parameter matches configuration
- Verify response Content-Type includes "application/json"
- Check that JSON is valid and parseable

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License
