JHubDemoDataProcessor
---------------------

Data Processor for JuliaHub project deployment demos. Reads instrument data from DB Service and writes back processed data at periodic intervals.

![Diagram](diagram.jpg)

- `bin/main.jl` is the entrypoint for execution on JuliaHub platform
- A `Manifest.toml` needs to be generated before deploying this project. You can generate a `Manifest.toml` file by instantiating the Project.toml locally or on the JuliaHub IDE (recommended) by clicking "Launch" on the project page. The julia version used for instantiation should match the version on JuliaHub.
- Recommended to use instance type with at least 8GB memory.
- Doesn't respond to requests so it doesn't matter what port number you mention in project deployment settings.
- The DB service endpoint is hardcoded in src/DataProcessor.jl. Ideally this should be configured as an environment variable but that feature is not available right now. **Make sure to edit this for your deployment see [DB Service](https://github.com/nkottary/JHubDemoDBService) for more details**.
