
JEKYLL_CMD = jekyll serve --drafts
IMAGE_DIR = images

thumbs:
	for dir in $(IMAGE_DIR)/*/; do \
		ext=$$(find $$dir -type f | head -n 1 | sed -e 's/.*\.//'); \
		echo "$$dir : $$ext"; \
		sh produce-thumbnails.sh $$dir $$ext; \
	done

local:
	$(JEKYLL_CMD)

# Run in Ubunutu Docker container
#	-p 4000:4000 forwards the default server port to the host
docker:
	sudo docker run -p 4000:4000 --volume="$(shell pwd):/srv/jekyll" -it jekyll/builder:3.8 $(JEKYLL_CMD)
