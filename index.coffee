_     = require 'underscore'
flow  = require 'flow-coffee'
http  = require 'http'

pg    = null
pgn   = null
redis = null
cbcli = null
cb_mc = null
es    = null

# for elastic via http
# http.globalAgent.maxSockets = 5

cbconfig = 
  user:     'Administrator'
  password: 'qwerty'
  hosts:    [ 'localhost:8091' ]
  bucket:   'default'

pgconfig = 'tcp://max:1@localhost/test'

item = id: 1, data: 2

################################################################################
setups =
  redis: (done) ->
    redis = require('redis').createClient()
    redis.set '1', JSON.stringify(item), done

  couchbase: (done) ->
    require('couchbase').connect cbconfig, (err, bucket) ->
      return done err if err
      cbcli = bucket
      cbcli.set '1', item, done

  couchbase_memcached: (done) ->
    cb_mc = new (require 'memcached')('localhost:11211')
    cb_mc.set '2', item, 0, done

  elastics: (done) ->
    es = new (require 'elastics')
      index: 'bench'
      type: 'test'
    es.set 1, item, done

  pg: (done) ->
    pg = new (require('pg')).Client pgconfig
    pg.connect (err) ->
      return done err if err
      pg.query "
      DROP TABLE IF EXISTS test;
      CREATE TABLE test
      (
        id serial NOT NULL,
        data integer,
        CONSTRAINT test_pkey PRIMARY KEY (id)
      )", (err) ->
        return done err if err
        pg.query "INSERT INTO test (id, data) VALUES (1, 2)", done

  pgnative: (done) ->
    pgn = new require('pg').native.Client pgconfig
    pgn.connect done

################################################################################

bm_defaults =
  requests:   10000
  concurrent: 50
  type:       'async'

benchmarks = []

################################################################################
benchmarks.push _.extend {}, bm_defaults,
  description:  'redis'
  method:  (done) ->
    redis.get '1', (err, data) ->
      done err, JSON.parse data

# benchmarks.push _.extend {}, bm_defaults,
#   description:   'couchbase'
#   method:  (done) ->
#      cbcli.get '1', done

# benchmarks.push _.extend {}, bm_defaults,
#   description:   'elastics'
#   method:  (done) ->
#      es.get 1, done

benchmarks.push _.extend {}, bm_defaults,
  description:   'couchbase_memcached'
  method:  (done) ->
    cb_mc.get '2', done

# benchmarks.push _.extend {}, bm_defaults,
#   description:   'couchbaseRest'
#   method: (done) ->
#     req = http.get 'http://localhost:8092/default/1', (data) ->
#       done null, data
#     .on 'error', (err) -> done err

# benchmarks.push _.extend {}, bm_defaults,
#   description:   'pg'
#   method:  (done) ->
#     pg.query "SELECT FROM test WHERE id = 1", done

# benchmarks.push _.extend {}, bm_defaults,
#   description:   'pg.native'
#   method:  (done) ->
#     pgn.query "SELECT FROM test WHERE id = 1", done

################################################################################
module.exports = (done) ->
  flow.exec(
    ->
      # uncoment needed setups
      setups.redis @multi()
      # setups.elastics @multi()
      setups.couchbase_memcached @multi()
      setups.couchbase @multi()
      # setups.pg @multi()
      # setups.pgnative @multi()
      @multi() null
    -> done null, benchmarks
  )
