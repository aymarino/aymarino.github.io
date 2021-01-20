
local:
	jekyll serve --drafts

# Run in Ubunutu Docker container
#	-p 4000:4000 forwards the default server port to the host
docker:
	sudo docker run -p 4000:4000 --volume="$(shell pwd):/srv/jekyll" -it jekyll/builder:3.8 jekyll serve --drafts
