# .NET Ruleset — C# / .NET Best Practices

Activate by adding `dotnet` to the `rulesets` list in `.csi.yml`.

## Rules

### DN-001: Use `Directory.Build.props` for shared settings
Multi-project solutions should use `Directory.Build.props` to centralize package versions, target frameworks, and common properties.

### DN-002: `appsettings.json` should not contain secrets
Connection strings, API keys, and passwords should use `appsettings.Development.json` (gitignored), environment variables, or Azure Key Vault — never committed in `appsettings.json`.

### DN-003: Enable nullable reference types
Projects targeting .NET 6+ should have `<Nullable>enable</Nullable>` in their `.csproj` files.

### DN-004: No unused NuGet packages
`.csproj` `<PackageReference>` entries should correspond to actual `using` statements in code. Remove unused packages.

### DN-005: Use `ILogger<T>` over `Console.WriteLine`
Services and libraries should inject `ILogger<T>` for logging instead of using `Console.WriteLine`.

### DN-006: Async methods should end with `Async`
Public async methods should follow the naming convention `DoSomethingAsync()`.

### DN-007: `bin/` and `obj/` must be gitignored
Build output directories must appear in `.gitignore`.

### DN-008: Use `ConfigureAwait(false)` in library code
Library code (not ASP.NET controllers) should use `ConfigureAwait(false)` on awaited calls to avoid deadlocks.

### DN-009: Target framework should be current
`.csproj` `<TargetFramework>` should reference a supported .NET version (not end-of-life).

### DN-010: Solution file should reference all projects
The `.sln` file should include all `.csproj` files in the repository, and no references to deleted projects.
