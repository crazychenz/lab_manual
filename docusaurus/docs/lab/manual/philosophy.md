---
sidebar_position: 10
title: My Documentation Philosophy
draft: false
---

## Philosophy

To recap, we now have an environment where we can securely store our credentials, a fully operational HTTPS context via a local DNS/CA/WebServer/ReverseProxy, as well as a repository to store all of our project files, artifacts, and revisions.

The last significant part of the baseline is a way to document our system.

Many many engineers will "Ugh" at the idea of documentation, myself included. In my years of developing and engineering solutions, I've found that its 100% a slog to write documentation for others. Especially when you don't know their background, how they think, or what really matters to them (i.e. the generic audience). If this is a challenge or obstacle for you, I would advise you immediately stop writing for others! Instead, **write documention for yourself!** 

I used to tell folks that we write documentation for the "next guy". That guy that we hire half way through a project to help us get over the finish line, or for the people that'll take on the life cycle management and maintenance of the project after we've left. OVer the past decade, I've personally found this to be inadequate because this is still writing for someone I do not know. 

In short, when writing documentation, don't only write it for yourself ... write it for your _future_ self! What I mean by this is, write the exact documentation **I** would want to see if I were thrown into my own project without any background or knowledge of how it works or is assembled. Please don't get me wrong, you should only write documentation for yourself and not take anyone else's feelings into consideration.

This is not a systems engineering exercise in wasting time and money for the comfort of non-techies, this is not an exhaustive write up for someone that slept through or shrugged off some training or a critical chapter in a book. This documentation is for you, the person who comes to the topic with a background and knowledge. Perhaps the knowledge becomes forgotten in the myriad of projects or responsibilities through out the months or years following your initial development. The documentation you write should be just enough to to refresh your mind on the knowledge required to move forward.

Now that we have that out of the way, I'd also highly recommend that you always write your documentation in relatively timeless terms (refrain from slang), use grammar well, and spell words correctly. Attempt to let future you be proud of its past, even though you'll inevitably fail at this.

## Tools

Now that we know our audience, lets talk about my personal preferences for documentation. The gist is that I'll be using Markdown, Docusaurus, NodeJS, Docker, and Caddy to manage and present documentation.

### Markdown

When I was first exposed to Wikipedia (circa 2004), I was amazed at how the Wiki syntax used was so limited (in contrast to something like Microsoft Word). How could you develop such a wonderful product and leave out so many features? Turns out that this was a very deliberate decision. Limiting the bells and whistles in how we can present the information forces the author to think in words instead of excessively complex visual aids. Fast forward to the rise of GitHub and you'll find Markdown following a similar approach (i.e. limited features in favor of more uniform presentation). 

Other than Markdown and WikiInfo, I've also used ReStructuredText (RST), LaTeX, and a few others. All of these have their pros and cons, but I've really been biased towards Markdown for its readability in plain text as well as the wealth of community support in conversions to other formats. I can write a document in pure Markdown and easily convert it to a `man` page, PDF, `epub`, HTML, and many other common formats. This manual is written in Markdown, albeit presented by Docusaurus and sometimes using MDX (for excessive visual aids `;-)`).

### Docusaurus & React & MDX

Sometime just before 2020, I learned about [Jamstack](https://jamstack.org/generators/). Regardless of what anyone thinks of Jamstack, my takeaway was that it was now a normal business process to _compile_ websites and upload the output to content delivery systems (CDNs). After some market research and experimentation, I finally landed on Facebook's Docusaurus as the **best** framework for my desired workflow that supported blogging and documentation presentation. For me, nothing has come close in terms of polish, feature set, extensibility, and support. This manual is implemented with Docusaurus.

Docusaurus is written in TypeScript/Javascript and built/developed with `nodejs`. It utilizes Facebook's other significant Javascript/Typescript library React. React and Babel provide what is known as JSX (JavaScript Extension). This syntax permits the interlacing of XML elements (that represent other bit of Javascript) within Javascript. (C/C++ developers can think of it as a preprocessor of sorts.) If you combine JSX and Markdown, you get MDX. MDX permits XML elements (representing Javascript) to be dropped directly into your documentation to add advanced features to the Markdown.

MDX breaks a lot that is good about Markdown's portability. Fortunately, the violating syntax is only XML and therefore can often be ignore by browsers or other Markdown readers. The reality is that there are some situations where you simply want to have a more interactive feature set for your documentation. For example, I write every blog article in Markdown, but all of my Markdown articles are actually MDX so that they can include the comment section (backed by GitHub issues).
