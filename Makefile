
jss := $(shell find . -name "*.js" -print)

all : coffee

clean : 
	find . -name "*.js" -exec rm {} \;

coffee : 
	coffee server.coffee

fixtures : flushdb js
	node tools/load.js tools/fixtures.json

flushdb : 
	coffee tools/flushdb.coffee

js : $(jss)
	find . -name "*.coffee" -exec coffee -c {} \;

load : flushdb js
	node tools/load.js dump/dump.json

node : js
	node server.js

save : js
	mkdir -p dump/
	node tools/save.js dump/dump.json

tests: js
	node tests/all.js

