# health_report(): the treatment section of each format

    Code
      writeLines(body("markdown"))
    Output
      ###  Tf usage
      
      **Treatment:** Replace `T` with `TRUE` and `F` with `FALSE`
      
      ```r
      # Before
      result <- T
      
      # After
      result <- TRUE
      ```
      
      **Affected Areas:**
      - `test.R:1`
      
      
    Code
      writeLines(body("text"))
    Output
          Tf usage
            - test.R:1
            Treatment: Replace `T` with `TRUE` and `F` with `FALSE`
      
              # Before
              result <- T
              
              # After
              result <- TRUE
      
      
    Code
      writeLines(body("html"))
    Output
      <li><strong>Tf usage</strong>
      <ul>
      <li>test.R:1</li>
      </ul>
      <p><strong>Treatment:</strong> Replace <code>T</code> with <code>TRUE</code> and <code>F</code> with <code>FALSE</code></p>
      <pre><code># Before
      result &lt;- T
      
      # After
      result &lt;- TRUE</code></pre>
      </li>
      </ul>

