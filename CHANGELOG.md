## 0.2.1

### Bug fixes

- Run the database exception handler at the bottom of the stack to ensure it will take priority over other exception handlers

## 0.2.1

### Bug fixes

- Only hijack the database connection for requests in secondary regions

## 0.2.0

### Features

- Add `Fly-Region` and `Fly-Database-Host` response headers for easier debugging
