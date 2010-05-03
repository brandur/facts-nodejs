
jss := $(shell find . -name "*.js" -print)

all : coffee

clean : 
	find . -name "*.js" -exec rm {} \;

coffee : 
	coffee server.coffee

js : $(jss)
	find . -name "*.coffee" -exec coffee -c {} \;

node : js
	node server.js

tests: js
	node tests/all.js

