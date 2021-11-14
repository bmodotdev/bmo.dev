# [bmo.dev](https://bmo.dev) source code
Currently, this is a simple static HTML website.

## Dependencies
* bash
* [Pandoc](https://pandoc.org/)
* Perl’s [Template::Toolkit](https://metacpan.org/pod/Template::Toolkit)
* Perl’s [Mojo](https://metacpan.org/pod/Mojo)
* John Otander’s [retro](https://github.com/markdowncss/retro) markdown theme (included as a git submodule)

## Source files
The [source files](./src) are markdown files which allows me to write content than can be translated
into virtually any document. I [use](https://github.com/bmodotdev/bmo.dev/blob/40eaeed2003d6b4a6a371bf5ed08461f348f92d8/website/make.bash#L112)
Pandoc to translate markdown to HTML, and John Otander’s markdown theme to style it.

On top of that, each markdown file is templated using Perl’s Template::Toolkit, and rendered recursively
[using ](https://github.com/bmodotdev/bmo.dev/blob/40eaeed2003d6b4a6a371bf5ed08461f348f92d8/website/make.bash#L86)
`ttree`.
This makes it extremely flexible and effortless to write new content quickly.

## Building
I created a simple bash script, [make.bash](./make.bash) to automate the development and build processes.

```
$ ./make.bash help
Automated targets:
        help:           Show this help message
        clean:          Clean up directories
        dist:           Clean, make css, make markdown, make html
        serve:          Make dist, then serve the dist directory contents using Mojo

Manual targets:
        css:            Make CSS files
        markdown:       Make markdown files
        html:           Make html files
```
