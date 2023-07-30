# aymarino - Blog

[Blog!](https://aymarino.github.io)

Template modified from [Jekyll Now](https://github.com/barryclark/jekyll-now).

## Installation

```sh
sudo apt-get install ruby-full build-essential zlib1g-dev
sudo gem install jekyll bundler
```

## Notes

* Run without container (with `jekyll` installed): `jekyll serve`
* Run in Ubuntu [docker container](https://hub.docker.com/r/jekyll/jekyll/):

```sh
sudo docker run -p 4000:4000 --volume="$PWD:/srv/jekyll" -it jekyll/builder:3.8 jekyll serve
```

* Convert .heic images to .jpg: `mogrify -format jpg *.heic`
* Strip EXIF data: `mogrify -strip *.jpg`
