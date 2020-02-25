.PHONY: all clean

all: README.html

README.adoc: README.adoc.erb
	erb -r ./erb_helper.rb README.adoc.erb > README.adoc

README.html: README.adoc
	asciidoctor README.adoc -o README.html

clean:
	- rm README.adoc README.html
