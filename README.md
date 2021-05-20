# aymarino - Blog

[Blog!](https://aymarino.github.io)

Template modified from [Jekyll Now](https://github.com/barryclark/jekyll-now).

## Notes

* Run in Ubuntu [docker container](https://hub.docker.com/r/jekyll/jekyll/):

```sh
sudo docker run -p 4000:4000 --volume="$PWD:/srv/jekyll" -it jekyll/builder:3.8 jekyll serve
```

* Convert .heic images to .jpg: `mogrify -format jpg *.heic`
