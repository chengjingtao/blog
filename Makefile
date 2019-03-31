SITE = http://chengjt.site

run:
	hugo server --buildDrafts

build:
	hugo --baseUrl=$(SITE)
