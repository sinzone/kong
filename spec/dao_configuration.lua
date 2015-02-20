return {
  cassandra = {
    hosts = "127.0.0.1",
    port = 9042,
    timeout = 1000,
    keepalive = 60000,
    keyspace = "kong_tests"
  }
}
