all: site
	./site build

site: site.hs
	ghc --make -fwarn-unused-imports site

run: site
	./site watch

deploy:
	./deploy.sh

.PHONY: run deploy
