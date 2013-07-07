_     = require 'underscore'
flow  = require 'flow-coffee'
http  = require 'http'

connects = {}

# for elastic via http
# http.globalAgent.maxSockets = 5

cbconfig = 
  user:     'Administrator'
  password: 'qwerty'
  hosts:    [ 'localhost:8091' ]
  bucket:   'default'

pgconfig = 'tcp://max:1@localhost/test'

item = id: 1, data: 2

bm_defaults =
  requests:   10000
  concurrent: 50
  type:       'async'

benchmarks_enabled = [
  'redis'
  'couchbase'
  'couchbase_memcached'
  'couchbaseRest'
  'elastics'
  'elastics_query'
  'pg'
  'pgnative'
]

################################################################################
benchmarks_available =
  redis:
    setup: (done) ->
      connects.redis = require('redis').createClient()
      connects.redis.set '1', JSON.stringify(item), done
    benchmark: (done) ->
      connects.redis.get '1', (err, data) ->
        done err, JSON.parse data

  couchbase:
    setup: (done) ->
      require('couchbase').connect cbconfig, (err, bucket) ->
        return done err if err
        connects.cbcli = bucket
        connects.cbcli.set '1', item, done
    benchmark: (done) ->
      connects.cbcli.get '1', done

  couchbase_memcached:
    setup: (done) ->
      connects.cb_mc = new (require 'memcached')('localhost:11211')
      connects.cb_mc.set '2', item, 0, done
    benchmark: (done) ->
      connects.cb_mc.get '2', done

  couchbaseRest:
    benchmark: (done) ->
      req = http.get 'http://localhost:8092/default/1', (data) ->
        done null, data
      .on 'error', (err) -> done err

  elastics:
    setup: (done) ->
      connects.es = new (require 'elastics')
        index: 'bench'
        type: 'test'
      connects.es.set 1, item, done
    benchmark: (done) ->
      connects.es.get 1, done

  elastics_query:
    benchmark: (done) ->
      connects.es.search data: query: match_all: {}, done

  pg:
    setup: (done) ->
      connects.pg = new (require('pg')).Client pgconfig
      connects.pg.connect (err) ->
        return done err if err
        connects.pg.query "
        DROP TABLE IF EXISTS test;
        CREATE TABLE test
        (
          id serial NOT NULL,
          data integer,
          CONSTRAINT test_pkey PRIMARY KEY (id)
        )", (err) ->
          return done err if err
          connects.pg.query "INSERT INTO test (id, data) VALUES (1, 2)", done
    benchmark: (done) ->
      connects.pg.query "SELECT FROM test WHERE id = 1", done

  pgnative:
    setup: (done) ->
      connects.pgn = new require('pg').native.Client pgconfig
      connects.pgn.connect done
    benchmark: (done) ->
      connects.pgn.query "SELECT FROM test WHERE id = 1", done

################################################################################
benchmarks  = []
setups      = []

for name in benchmarks_enabled
  continue unless benchmark = benchmarks_available[name]
  setups.push benchmark.setup if benchmark.setup
  benchmarks.push _.extend {}, bm_defaults,
    description:  name
    method:       benchmark.benchmark

################################################################################
module.exports = (done) ->
  flow.exec(
    ->
      setup @multi() for setup in setups
      @multi() null
    (err) ->
      if err
        console.log err
        return done err, []
      done null, benchmarks
  )
