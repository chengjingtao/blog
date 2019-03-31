---
title: "Translate Using Go Modules"
date: 2019-03-31T11:41:59+08:00
tags: ["golang", "translate"]
categories: ["pages"]
---

原文链接 Go Blog [Using Go Modules](https://blog.golang.org/using-go-modules)

# 介绍

Go 1.11 和 Go1.12 版本中已经包含了对 Golang依赖管理`modules`的基本支持, 它将会使依赖的版本信息更加明确，并且更容易管理。
这篇文章将会对其进行一个入门级别的基本操作介绍。 下篇文章将会介绍如何releasing modules.

一个Module 将会是一系列 Go packages 的合集。在go packages的目录树的根目录，会有一个 go.mod 文件。go.mode 文件中定义了 module的 module path。
这个module path 将会用来作为package导入的根路径。每个依赖包都会提供一个 module path和 Semantic Version。

在 Go 1.11 中， 如果在 ${GOPATH}/src 目录以外，执行go command， 如果当前目录或者父目录存在 go.mode文件，则将会启用 go module。
如果在 ${GOPATH}/src 下， 为了保证兼容性，go command 将会仍然运行在 旧的 `GOPATH`的模式下， 即使找到了相应的 go.mod 文件。 详细可以查看 [go command文档](https://golang.org/cmd/go/#hdr-Preliminary_module_support)
从 Go1.13 开始， `Go Module` 模式将会在所有情景下被默认启用。

本文 将会从 平时的 Go 开发中，最常见的使用 modules 的以下几种操作进行介绍：

- 创建一个新的 module
- 添加依赖
- 升级依赖
- 增加一个新的主版本依赖
- 更新依赖的主版本。
- 移除无用的依赖

# 创建 module

让我们创建一个新的module

在 $GOPATH/src 目录外， 创建一个 空目录， 并且在里边创建一个 hello.go文件

``` go
package hello

func Hello() string {
    return "Hello, world."
}
```
增加单元测试， hello_test.go
```go
package hello

import "testing"

func TestHello(t *testing.T) {
    want := "Hello, world."
    if got := Hello(); got != want {
        t.Errorf("Hello() = %q, want %q", got, want)
    }
}
```
这时， 当前目录包含一个 package, 并非一个 module。 因为现在没有 go.mod文件。 
如果我们当前的目录是 /home/gopher/hello， 运行 `go test` 之后， 我们会看到
```
PASS
ok      _/home/gopher/hello    0.020s
$
```
最后一行中， 汇总了整个包的测试结果。由于我们不在 ${GOPATH}中， 也不在 任何 module 中，go命令不知道当前目录对应的 导入路径是什么，只能依靠目录名称 ` _/home/gopher/hello` 来提供了一个假的包名。

现在我们使用 `go mod init`命令，在当前目录 初始化一个  go module. 然后 再执行一下 `go test`:

```bash
$ go mod init example.com/hello
go: creating new go.mod: module example.com/hello
$ go test
PASS
ok      example.com/hello    0.020s
$
```
祝贺你，你已经完成了你的第一个 go module。
`go mod init` 命令写入了一个 `go.mod`文件
```
$ cat go.mod
module example.com/hello

go 1.12
$
```
go.mod 文件只会在module的根目录出现。子目录中的包的导入路径，将会是module path 加上 子目录的相对路径。举个例子， 我们在当前目录下创建了一个子目录`world` , 我们不需要再在world 目录下执行 go mod init , 当然我们也不想这么做。 `world` 包的导入路径将会自动为 `example.com/hello/world`.

# 添加一个依赖
Go modules 的主要意图是提升使用其他开发者编写的代码时的体验。
我们现在更改hello.go文件，通过引用 `rsc.io/quote`,来实现`Hello`方法
```go
package hello

import "rsc.io/quote"

func Hello() string {
    return quote.Hello()
}
```
再次运行测试：
```bash
$ go test
go: finding rsc.io/quote v1.5.2
go: downloading rsc.io/quote v1.5.2
go: extracting rsc.io/quote v1.5.2
go: finding rsc.io/sampler v1.3.0
go: finding golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c
go: downloading rsc.io/sampler v1.3.0
go: extracting rsc.io/sampler v1.3.0
go: downloading golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c
go: extracting golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c
PASS
ok      example.com/hello    0.023s
$
```
go command 将会解析go.mod文件中列出的依赖版本。当发现导入了一个在go.mod中不存在的module的package时，go command 将会自动的查找对应的module，并且将他加入到go.mod文件中，此时会使用其最新（Latest）版本。（"Latest"的含义是最近的被tag为stable的版本，或者最近的prerelease的版本， 或者最近的没有tag的版本）。在这个例子里， `go test`命令将新导入的包`rsc.io/quote`的module 解析为`rsc.io/quote v1.5.2`， 也自动下载了被`rsc.io/quote v1.5.2`依赖的两个依赖：`rsc.io/sampler`, `golang.org/x/text`。 只有直接依赖，才会记录在go.mod文件中。
```
$ cat go.mod
module example.com/hello

go 1.12

require rsc.io/quote v1.5.2
$
```
接下来再执行`go test`时，就不需要再重复以上过程，因为当前的`go.mo`文件已经是最新的了，所有需要的modules都缓存在了本地(${GOPATH}/pkg/mod):
```
$ go test
PASS
ok      example.com/hello    0.020s
$
```
需要注意的是，虽然使用go命令添加依赖虽然很快也很容易，但并不是没有任何代价的。因为，当前我们的module上依赖于一个新的package，都存在例如正确性，安全性，许可证等等，这里只是举几个例子。更详细的信息，可以参考Russ Cox的博客的文章 [Our Software Dependency Problem](https://research.swtch.com/deps).

正如我们刚才看到的， 添加一个依赖的时候，同时也会把其所依赖的内容加载进来。命令`go list -m all`将会把当前module的所有依赖全部打印出来。
```
$ go list -m all
example.com/hello
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c
rsc.io/quote v1.5.2
rsc.io/sampler v1.3.0
$
```
在`go list`的输出中，第一行总是当前的module， 这个module是`main module`。下边是根据module path 排序的其他依赖。

对于那些没有tag的module， go命令将会采用如下的语法进行记录， ` golang.org/x/text version v0.0.0-20170915032832-14c0d48ead0c` 就是`pseudo-version`的一个例子。

除了go.mod文件，go命令还会在go.sum文件中记录每个module的hash值。
```
$ cat go.sum
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c h1:qgOY6WgZO...
golang.org/x/text v0.0.0-20170915032832-14c0d48ead0c/go.mod h1:Nq...
rsc.io/quote v1.5.2 h1:w5fcysjrx7yqtD/aO+QwRjYZOKnaM9Uh2b40tElTs3...
rsc.io/quote v1.5.2/go.mod h1:LzX7hefJvL54yjefDEDHNONDjII0t9xZLPX...
rsc.io/sampler v1.3.0 h1:7uVkIFmeBqHfdjD+gZwtXXI+RODJ2Wc4O7MPEh/Q...
rsc.io/sampler v1.3.0/go.mod h1:T1hPZKmBbMNahiBKFy5HrXp6adAjACjK9...
$
```
go.sum 文件用来确保，下次下载同一个module的同一个版本时，获得的内容是完全一致的，避免发生一些不期望的变化，不论是处于恶意，偶然的或者是其他原因。`go.mod`和`go.sum`文件都应该被提交到版本库中。

# 更新依赖
在Go modules模式下，使用 semantic version。 semantic version 由三部分组成，主版本，次版本和补丁版本。例如，v0.1.2, 主版本号是0，次版本号是1，最后的补丁版本是2。我们更新几个次版本。下一章节，更新主版本。

从`go list -m all`的输出中，我们可以看到， 我们依赖的 `golang.org/x/text` module的版本是 untagged version。现在，我们把这个module更新到最近的版本，然后运行测试：
```
$ go get golang.org/x/text
go: finding golang.org/x/text v0.3.0
go: downloading golang.org/x/text v0.3.0
go: extracting golang.org/x/text v0.3.0
$ go test
PASS
ok      example.com/hello    0.013s
$
```
可以看到，测试通过。让我们再使用`go list -m all`命令看下：
```
$ go list -m all
example.com/hello
golang.org/x/text v0.3.0
rsc.io/quote v1.5.2
rsc.io/sampler v1.3.0
```
看下 go.mod文件
```
$ cat go.mod
module example.com/hello

go 1.12

require (
    golang.org/x/text v0.3.0 // indirect
    rsc.io/quote v1.5.2
)
$
```
` golang.org/x/text`已经被更新到了最新的版本`v0.3.0`.而且go.mod 文件中也更新到了指定的版本v0.3.0。并且，有一个indirect注释，来说明该项内容是非直接的依赖。可以通过go help modules 查看更多信息。

现在，我们试着将`rsc.io/sampler`的次版本进行更新。使用同样的方法，`go get` 然后 `go test`:
```
$ go get rsc.io/sampler
go: finding rsc.io/sampler v1.99.99
go: downloading rsc.io/sampler v1.99.99
go: extracting rsc.io/sampler v1.99.99
$ go test
--- FAIL: TestHello (0.00s)
    hello_test.go:8: Hello() = "99 bottles of beer on the wall, 99 bottles of beer, ...", want "Hello, world."
FAIL
exit status 1
FAIL    example.com/hello    0.014s
$
```
测试失败了，测试结果显示，最新的版本和我们当前使用的版本是不兼容的。我们看下module `rsc.io/sampler`的所有可用版本：
```
$ go list -m -versions rsc.io/sampler
rsc.io/sampler v1.0.0 v1.2.0 v1.2.1 v1.3.0 v1.3.1 v1.99.99
$
```
我们最开始使用的版本是v1.3.0; 但是v1.99.99显然是不行的，我们试着用v1.3.1这个版本：
```
$ go get rsc.io/sampler@v1.3.1
go: finding rsc.io/sampler v1.3.1
go: downloading rsc.io/sampler v1.3.1
go: extracting rsc.io/sampler v1.3.1
$ go test
PASS
ok      example.com/hello    0.022s
$
```
注意，go get 参数中，指明了一个明确的版本v1.3.1。实际上，go get 之后都会有一个明确的版本，默认是@latest，正如上文中的的例子。

# 增加一个新的主版本依赖
现在，在我们的包里边增加一个新的方法`func Proverb`， 这个方法通过调用包`rsc.io/quote/v3`中的quote.Concurrency返回 Go concurrency proverb。 首先， 我们先更新 hello.go文件，增加这个新的func
```go
package hello

import (
    "rsc.io/quote"
    quoteV3 "rsc.io/quote/v3"
)

func Hello() string {
    return quote.Hello()
}

func Proverb() string {
    return quoteV3.Concurrency()
}
```
然后在测试文件中添加新的测试：
```go
func TestProverb(t *testing.T) {
    want := "Concurrency is not parallelism."
    if got := Proverb(); got != want {
        t.Errorf("Proverb() = %q, want %q", got, want)
    }
}
```
然后运行测试：
```
$ go test
go: finding rsc.io/quote/v3 v3.1.0
go: downloading rsc.io/quote/v3 v3.1.0
go: extracting rsc.io/quote/v3 v3.1.0
PASS
ok      example.com/hello    0.024s
$
```
注意，现在我们的package同时依赖rsc.io/quote和 rsc.io/quote/V3:
```
$ go list -m rsc.io/q...
rsc.io/quote v1.5.2
rsc.io/quote/v3 v3.1.0
$
```
go module的不同主版本(v1, v2 等等)使用不同的module path。从 v2 版本开始，module的路径必须以主版本号结尾。 举个 例子， rsc.io/quote的v3版本不再是 rsc.io/quote 了， 而是 rsc.io/quote/v3。  这个约定叫做 [semantic import versioning](https://research.swtch.com/vgo-import),为不兼容的版本提供了不同的名字。对比来看， rsc.io/quote的 v1.6.0 版本应当是向下兼容的。例如v1.5.2版本。所以，他仍然使用 rsc.io/quote版本。（在上一章节中，我们使用的rsc.io/sampler v1.99.99 应当是兼容 rsc.io/sampler v1.3.0, 然后由于一些bug或者一些非正确的客户端假设都可能导致以上问题的出现）。

go command 允许一个构建中，只包含一个module的一个特定的主版本， 这意味着，每个主版本的module 只能有一个，例如 rsc.io/quote， rsc.io/quote/v2, rsc.io/quote/v3 等等。对于特定的module path 如果存在可能重复的情况，这给出了一个清晰的规则：对于一个程序来讲，不应该同时使用 rsc.io/quote v1.5.2 和 rsc.io/quote v1.6.3 。 但是允许使用不同的主版本（因为他们是不同的module path）来使得 调用module的人能够对module 进行主版本的升级。举个例子，在我们还没有准备好升级rsc.io/quote v1.5.2的情况下， 我们可以同时使用 rsc.io/quote/v3 v3.1.0中的quote.Concurrency。这种增量式的迁移在一些大型的工程或者代码库中尤为重要。

# 更新依赖的主版本

我们继续完成，我们从 rsc.io/quote 到 rsc.io/quote/v3 版本的迁移。因为主版本发生了变化，我们应当预料到， 会有一些API 发生了变化，可能被删除， 更改，重命名等等，总之是一种非兼容的形式。通过阅读相关文档，我们可以了解到 Hello 方法 变成了 HelloV3:
```
$ go doc rsc.io/quote/v3
package quote // import "rsc.io/quote"

Package quote collects pithy sayings.

func Concurrency() string
func GlassV3() string
func GoV3() string
func HelloV3() string
func OptV3() string
$
```
（输出的内容中有一个[已知的bug](https://github.com/golang/go/issues/30778)，显示的 import path 错误的移除了 /v3.
(译者注: 我在go version go1.11 darwin/amd64环境下输出正常package quote // import "rsc.io/quote/v3" )

我们可以更新 quote.Hello() 为 quoteV3.HelloV3():
```go
package hello

import quoteV3 "rsc.io/quote/v3"

func Hello() string {
    return quoteV3.HelloV3()
}

func Proverb() string {
    return quoteV3.Concurrency()
}
```
此时，没有必要再重命名导入的包了。 所以， 我们可以改成：
```go
package hello

import "rsc.io/quote/v3"

func Hello() string {
    return quote.HelloV3()
}

func Proverb() string {
    return quote.Concurrency()
}
```
再跑一下测试， 确保一些工作正常
```
$ go test
PASS
ok      example.com/hello       0.014s
```

# 移除不需要的依赖
代码中，我们已经完全移除了对 rsc.io/quote的依赖，但是 通过 `go list -m all` 命令和go.mod 文件中，我们仍然能够看到这个信息:
```
$ go list -m all
example.com/hello
golang.org/x/text v0.3.0
rsc.io/quote v1.5.2
rsc.io/quote/v3 v3.1.0
rsc.io/sampler v1.3.1
$ cat go.mod
module example.com/hello

go 1.12

require (
    golang.org/x/text v0.3.0 // indirect
    rsc.io/quote v1.5.2
    rsc.io/quote/v3 v3.0.0
    rsc.io/sampler v1.3.1 // indirect
)
$
```
为什么呢？因为使用诸如 go build 或者 go test的方式编译一个package的时候，能够很简单的告诉我们有些包缺失了，有些需要添加进去。但是，不能够确认哪些包能够被安全的移除。只能是在检查了module中的所有的 package （and all possible build tag combinations for those packages） 之后，才能确认有哪些依赖不需要使用了。传统的编译命令无法加载这些信息，所以不能安全的移除依赖。

`go mod tidy`命令可以用清理哪些不需要使用的依赖：
```
$ go mod tidy -v
unused rsc.io/quote
$ go list -m all
example.com/hello
golang.org/x/text v0.3.0
rsc.io/quote/v3 v3.1.0
rsc.io/sampler v1.3.1
$ cat go.mod
module example.com/hello

go 1.12

require (
    golang.org/x/text v0.3.0 // indirect
    rsc.io/quote/v3 v3.1.0
    rsc.io/sampler v1.3.1 // indirect
)

$ go test
PASS
ok      example.com/hello    0.020s
$
```

# 总结
Go modules 是接下来go的包管理机制。Go Module的功能在现在支持的Go 版本（Go 1.11 Go 1.12）中已经是可用的了。
这篇文字从以下方面介绍了 Go modules 的使用：

- go mod init 创建一个新的go module, 初始化一个 go.mod 文件来描述该 module
- go build , go test 以及其他的 基于package的编译命令，将会自动将所需要的依赖加入到go.mod文件中。
- go list -m all 将会打印当前module的所有依赖。
- go mod tidy 将会移除不需要的依赖。

我们鼓励大家在本地开发时，使用 modules , 并且将go.mod 和 go.sum文件加入到你的工程中。请通过发送[bug reports](https://golang.org/issue/new) 或者[experience reports](https://golang.org/wiki/ExperienceReports) 进行反馈，以帮助我们塑造Golang的包管理机制的未来。

感谢你的任何反馈，来帮我们提升modules.

By Tyler Bui-Palsulich and Eno Compton

原文链接 Go Blog [Using Go Modules](https://blog.golang.org/using-go-modules)