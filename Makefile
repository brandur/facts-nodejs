
jss := $(shell find . -name "*.js" -print)

clean : 
	find . -name "*.js" -exec rm {} \;

js : $(jss)
	find . -name "*.coffee" -exec coffee -c {} \;

node : js
	node server.js

