# lab_network_operations(): prints the treatment's literal braces

    Code
      res <- lab_network_operations(pkg)
    Message
      ! Potential unwrapped network operations
      * f.Rd (unwrapped network call in \examples)
      Treatment: Guard the request with `curl::has_internet()` or `interactive()`, in
      an `if` or `@examplesIf`, or wrap it in `\donttest{}`, so it fails gracefully
      without a connection

