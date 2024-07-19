#!/usr/bin/env Rscript --vanilla

args=commandArgs(trailingOnly=TRUE)

library(magick)

legendpath <- c(args[1])
graphpath <- c(args[2])
sampleid <- c(args[3])
outputdir <- c(args[4])
titlename <- paste("Circos plot for", sampleid, sep=" ")
pngname <- paste(sampleid,"_circos.png", sep = "")
outputfile <- paste(outputdir,pngname, sep = "/")

legend <- image_read(legendpath)
legend <- image_scale(legend, geometry = "250%x250%")
graph <- image_read(graphpath)
img <- c(graph,legend)

output <- image_append(img)
output <- image_annotate(output, text = titlename, size = 150, color = "black", gravity = "southeast")

image_write(output, path = outputfile, format = "png")
