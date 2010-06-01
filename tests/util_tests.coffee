assert: require "assert"
sys:    require "sys"

require "../lib/util"

# @todo: put in an actual BDD test suite
describe: require("sys").puts
it:       (s) -> require("sys").print "    $s"

exports.utilTests: -> [
    testSanitize
]

testSanitize: (ds, cb) ->
    describe "util.sanitize"
    it "should sanitize input, removing opportunity for XSS attacks"
    assert.ok sanitize("<em>emphasized</em>") is "emphasized"
    assert.ok sanitize("l1\r\n\r\nl2") is "l1\n\nl2"
    assert.ok sanitize("needs trim     <em></em>") is "needs trim"
    cb()

