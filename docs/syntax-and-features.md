# Go syntax and features

A ground-up tour of Go's syntax and language features, written for someone fluent in C++/C#. Each aspect is compared to what you already know, with examples, common cases, and best practices.

Current as of Go 1.26. Read [proj-structure.md](proj-structure.md) for how the files are organized; this doc is about the code inside them.

---

## 0. The mental shift

Before any syntax, internalize the philosophy — it explains every design decision that will otherwise feel weird:

- **Small language, big standard library.** Go has ~25 keywords (C++ has ~95, C# ~80). There is intentionally one way to do most things. Cleverness is discouraged.
- **No inheritance, no exceptions, no overloading, no generics-everywhere, no implicit conversions.** These aren't missing features — they were deliberately left out. Composition replaces inheritance; multiple return values replace exceptions.
- **Readability over expressiveness.** Code is read far more than written. Go optimizes for the reader, even at the cost of typing more.
- **The compiler is strict and fast.** Unused variables and imports are *compile errors*, not warnings. Formatting is non-negotiable (`gofmt`). This kills entire categories of bikeshedding.
- **Composition and interfaces, not class hierarchies.** If you try to write Go like C#, you'll fight the language. Stop modeling "is-a" trees; model behavior with small interfaces.

Analogy: Go feels like C in ergonomics and a garbage-collected, memory-safe language in practice — with first-class concurrency bolted on as the headline feature.

---

## 1. Program structure, packages, and `main`

Every Go file starts with a `package` declaration. The `main` package with a `main()` function is the entry point.

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go")
}
```

- **A package is a directory.** All `.go` files in one directory belong to the same package. There are no separate header/implementation files — no `.h`/`.cpp` split, no forward declarations. Declaration order within a package doesn't matter (unlike C++; like C#).
- **Imports are by path, used by package name.** `import "net/http"` makes the identifier `http` available. Unused imports are a compile error.
- **No semicolons** (the lexer inserts them; you never type them). **Braces are mandatory** and the opening brace must be on the same line — this is enforced, not stylistic.
- **Exported = capitalized.** `Println` is public because it starts with a capital letter; `parseHeader` is package-private. There is no `public`/`private`/`internal` keyword — visibility *is* the casing. (See §16.)

Analogy: a package is closer to a C# `namespace` that happens to map 1:1 to a folder and assembly boundary, than to a C++ translation unit.

---

## 2. Variables, constants, and zero values

```go
var a int = 10        // explicit type
var b = 10            // type inferred (still int)
c := 10               // short form, only inside functions; most common
var d int             // zero value: 0

var (                 // grouped declaration
    name string       // ""
    count int         // 0
    ready bool        // false
)

const Pi = 3.14159    // constants: compile-time, untyped by default
const MaxRetries = 3
```

Key differences from C++/C#:

- **The `:=` short form** declares *and* infers in one step, only inside functions. `var` works everywhere (including package level). Use `:=` by default inside functions; use `var` when you want the zero value or a package-level declaration.
- **Zero values, always.** Every type has a well-defined zero value and there is *no* uninitialized memory. `int` → `0`, `string` → `""` (not null), `bool` → `false`, pointers/slices/maps/interfaces/channels/funcs → `nil`. This is huge: a freshly declared struct is fully usable without a constructor.
- **No uninitialized-variable bugs**, but also **unused variables are a compile error**. This forces clean code and catches typos.
- **Constants are untyped until used.** `const Pi = 3.14` has no fixed type; it adopts a type at the point of use. This avoids the C++ `static const` / `constexpr` ceremony and lets one constant work as `float32` or `float64` as needed.

Best practice: prefer `:=` inside functions, group related `var`/`const` blocks, and lean on zero values instead of writing constructors that just set defaults.

---

## 3. Basic types

```go
// Integers: sized and signed/unsigned
int8 int16 int32 int64      uint8 uint16 uint32 uint64
int  uint                   // platform word size (32 or 64-bit)
uintptr                     // holds a pointer's bits

float32 float64
complex64 complex128        // yes, complex numbers are built in

bool
string                      // immutable, UTF-8 bytes
byte                        // alias for uint8
rune                        // alias for int32 — one Unicode code point
```

Differences that bite C++/C# developers:

- **No implicit numeric conversions. None.** `var x int32 = 5; var y int64 = x` is a *compile error*. You must write `y := int64(x)`. This eliminates a whole class of silent-truncation bugs but feels verbose at first.
- **`string` is immutable and UTF-8.** Indexing `s[i]` gives you a `byte`, not a character. Ranging over a string gives you `rune`s (code points). `len(s)` is the byte count, not the character count.
- **`byte` vs `rune`.** When you mean "raw data," use `[]byte`. When you mean "text characters," think in `rune`s. C++ `char`/`wchar_t`/`char32_t` confusion is replaced by these two clear aliases.
- **No `char` type** — a character literal `'a'` is a `rune` (an `int32`).

```go
s := "héllo"
fmt.Println(len(s))            // 6 — 'é' is two bytes in UTF-8
for i, r := range s {          // i = byte index, r = rune
    fmt.Printf("%d:%c ", i, r)
}
// 0:h 1:é 3:l 4:l 5:o
```

Best practice: convert `string` ↔ `[]byte` ↔ `[]rune` explicitly when you need to mutate or count characters. Use the `strings`, `strconv`, `unicode/utf8` packages instead of hand-rolling.

---

## 4. Control flow

Go has `if`, `for`, `switch`, and `goto`. That's it — no `while`, no `do-while`, no ternary operator.

### if

```go
if x > 0 {
    // ...
} else if x < 0 {
    // ...
}

// if with an init statement — scopes the variable to the if/else
if err := doThing(); err != nil {
    return err
}
// err is not visible here
```

- **No parentheses** around the condition; **braces always required** (no single-statement shortcut).
- **The init statement** (`if x := f(); cond`) is idiomatic and ubiquitous — it scopes a variable tightly to the branch. You'll see it constantly with error checks.
- **No ternary operator.** Use a full `if`. The Go team considers `a ? b : c` a readability trap. Write it out.

### for — the only loop

```go
for i := 0; i < 10; i++ { }      // classic
for x < 100 { }                  // "while"
for { break }                    // infinite loop
for i, v := range slice { }      // range over slice/array/map/string/channel
for range ch { }                 // range, ignoring values
```

- **`for` is the only loop keyword.** It covers `while` (`for cond {}`) and infinite loops (`for {}`).
- **`range`** iterates slices (index, value), maps (key, value — *random order!*), strings (byte-index, rune), and channels (values until closed). Map iteration order is deliberately randomized to stop you relying on it.
- Go 1.22+ made each loop iteration create a **fresh copy of the loop variable** — the old C#-closure-captures-the-same-variable footgun is gone.
- Go 1.23+ added **range-over-function** (iterators): `for v := range myIterator {}` where `myIterator` is a function. This is how you write custom iterators now.

### switch

```go
switch day {
case "Sat", "Sun":              // multiple values per case
    fmt.Println("weekend")
case "Mon":
    fmt.Println("ugh")
    fallthrough                 // explicit — cases do NOT fall through by default
default:
    fmt.Println("weekday")
}

switch {                        // no condition = switch on true; replaces if/else chains
case score >= 90:
    grade = "A"
case score >= 80:
    grade = "B"
}

switch v := x.(type) {          // type switch — see §9
case int:    ...
case string: ...
}
```

- **No implicit fall-through** — the opposite of C++/C#. Cases break automatically; use `fallthrough` to opt in (rare).
- **`switch {}` with no expression** is the idiomatic replacement for long `if/else if` chains.
- **Type switches** (`x.(type)`) branch on the dynamic type of an interface value — there's no C# pattern matching, this is the equivalent.

---

## 5. Functions

```go
func add(a, b int) int {           // shared type for consecutive params
    return a + b
}

func divmod(a, b int) (int, int) { // multiple return values
    return a / b, a % b
}

func parse(s string) (int, error) {   // the (result, error) idiom
    n, err := strconv.Atoi(s)
    return n, err
}

func sum(nums ...int) int {        // variadic
    total := 0
    for _, n := range nums {
        total += n
    }
    return total
}
```

What's new vs C++/C#:

- **Multiple return values are first-class** — not `out` params, not `std::tuple`, not `Tuple<T1,T2>`. This is *the* mechanism for returning a value plus an error (§10).
- **Named return values:**

  ```go
  func split(sum int) (x, y int) {   // x and y are pre-declared, zero-valued
      x = sum * 4 / 9
      y = sum - x
      return                          // "naked" return — returns x, y
  }
  ```
  Useful with `defer` to modify the result on the way out. Use sparingly — naked returns hurt readability in long functions.

- **No function overloading.** You cannot have two functions with the same name and different signatures. Use distinct names (`Print`, `Printf`, `Println`) or variadic params. This feels restrictive but eliminates overload-resolution surprises.
- **No default parameters.** Use variadic args, an options struct, or the functional-options pattern (a Go idiom: `New(WithTimeout(5), WithRetries(3))`).
- **Functions are values.** Assign them to variables, pass them, return them. Closures capture variables by reference:

  ```go
  func counter() func() int {
      n := 0
      return func() int { n++; return n }   // closure over n
  }
  ```

- **The blank identifier `_`** discards a return value you don't want: `_, err := f()`.

Best practice: return errors as the *last* value. Keep functions short. Prefer the functional-options pattern over giant config structs or many overloads.

---

## 6. Pointers

Go has pointers but **no pointer arithmetic** and no `->` operator.

```go
x := 42
p := &x          // p is *int, address of x
fmt.Println(*p)  // 42 — dereference
*p = 100         // x is now 100

func modify(p *int) { *p = 5 }   // pass a pointer to mutate the caller's value
```

- **`&` takes an address, `*` dereferences** — same as C++. But there is **no pointer arithmetic** (`p++` on a pointer is illegal). Memory is safe.
- **No `->`.** Field and method access through a pointer uses `.` and Go auto-dereferences: `p.Field`, not `p->Field`. The compiler figures it out.
- **`new(T)`** allocates a zeroed `T` and returns `*T`. Rarely used — `&T{}` is more common and clearer.
- **The compiler decides stack vs heap** via escape analysis. You don't `delete` or `free`; the GC handles it. Taking the address of a local and returning it is *safe and idiomatic* — the value escapes to the heap automatically (the opposite of C++, where returning `&local` is a dangling-pointer bug).
- **`nil` is the zero value** of a pointer. Dereferencing nil panics (runtime error), it doesn't corrupt memory.

```go
func newUser(name string) *User {
    return &User{Name: name}   // perfectly safe — escapes to heap
}
```

Best practice: pass pointers when you need to mutate the argument or when copying is expensive. Otherwise pass values — Go's value semantics are cheap and safe. Don't reach for pointers reflexively the way you might in C++.

---

## 7. Structs

```go
type User struct {
    ID    int
    Name  string
    Email string
}

u := User{ID: 1, Name: "Ann"}     // field names — preferred, order-independent
u2 := User{2, "Bob", "b@x.io"}    // positional — fragile, avoid for exported types
p := &User{Name: "Cara"}          // pointer to a struct literal
empty := User{}                    // all fields zero-valued, immediately usable
```

- **Structs are value types** (like C# `struct`, not `class`). Assignment and passing *copy* the whole struct. Use a pointer (`*User`) when you want reference semantics.
- **No constructors.** The zero value should be useful. When you need initialization logic, write a `New...` function returning the struct (or a pointer): `func NewUser(...) *User`.
- **No classes.** A struct is just data. Behavior is attached via methods (§8), not defined inside the struct body.
- **Struct tags** add metadata used by reflection-based libraries (JSON, DB, validation):

  ```go
  type User struct {
      ID    int    `json:"id"`
      Name  string `json:"name"`
      Email string `json:"email,omitempty"`
  }
  ```

- **Comparable** if all fields are comparable: `u1 == u2` compares field-by-field. (Structs containing slices/maps/funcs are not comparable.)
- **Anonymous structs** exist for one-off shapes (handy in tests and table-driven tests):

  ```go
  point := struct{ X, Y int }{1, 2}
  ```

Best practice: use field-named literals for anything exported. Make the zero value useful so callers can skip a constructor. Reserve `New...` functions for when there's real setup work.

---

## 8. Methods and receivers

Methods are functions with a **receiver** — they're declared *outside* the struct, anywhere in the same package.

```go
type Rectangle struct{ W, H float64 }

func (r Rectangle) Area() float64 {       // value receiver — gets a copy
    return r.W * r.H
}

func (r *Rectangle) Scale(f float64) {    // pointer receiver — can mutate
    r.W *= f
    r.H *= f
}

rect := Rectangle{3, 4}
fmt.Println(rect.Area())   // 12
rect.Scale(2)              // Go auto-takes &rect; rect is now {6, 8}
```

The single most important decision: **value receiver vs pointer receiver.**

- **Value receiver** `(r Rectangle)` — operates on a copy. Safe, can't mutate the original. Use for small, immutable-by-intent types.
- **Pointer receiver** `(r *Rectangle)` — operates on the original. Required to mutate, and avoids copying large structs.
- **Rule of thumb:** if *any* method needs a pointer receiver, make *all* methods on that type pointer receivers for consistency. Use pointer receivers for structs that are large or hold mutable state; value receivers for small value types (like a `time.Time`-style type).
- **You can attach methods to any named type you define**, not just structs:

  ```go
  type Celsius float64
  func (c Celsius) Fahrenheit() Celsius { return c*9/5 + 32 }
  ```
  You *cannot* add methods to types from other packages (no C# extension methods) — define a local named type first.

Analogy: receivers are like the implicit `this`/`self`, but explicit and named, and you choose copy vs reference semantics per method.

---

## 9. Interfaces — the heart of Go

This is where Go diverges most from C++/C#. **Interfaces are satisfied implicitly (structurally).** There is no `implements`, no `: IShape`, no inheritance. If a type has the right methods, it satisfies the interface — automatically.

```go
type Shape interface {
    Area() float64
    Perimeter() float64
}

// Rectangle satisfies Shape just by having these two methods.
// No declaration linking them. The compiler checks at assignment.
func describe(s Shape) {
    fmt.Printf("area=%.2f perim=%.2f\n", s.Area(), s.Perimeter())
}

describe(Rectangle{3, 4})   // works — Rectangle has both methods
```

Why this matters:

- **Duck typing, checked at compile time.** "If it has the methods, it is the interface." You can define an interface *after* the concrete types exist, even for types you don't own (define the interface in the consumer).
- **Small interfaces are idiomatic.** The standard library is full of one-method interfaces: `io.Reader`, `io.Writer`, `fmt.Stringer`, `error`. Compose behavior from tiny interfaces rather than designing big hierarchies. "The bigger the interface, the weaker the abstraction."
- **"Accept interfaces, return structs."** Functions take interface parameters (flexible) and return concrete types (informative). This is the foundational dependency-injection pattern (see proj-structure.md §3).
- **The empty interface `interface{}` / `any`** holds any value (like `object` in C# or `void*` minus the danger). `any` is an alias added in Go 1.18. Use sparingly — you lose type safety.

### Type assertions and type switches

```go
var x any = "hello"

s := x.(string)            // assert — panics if x is not a string
s, ok := x.(string)        // comma-ok form — ok is false instead of panicking

switch v := x.(type) {     // type switch
case string:
    fmt.Println("string of len", len(v))
case int:
    fmt.Println("int", v)
default:
    fmt.Println("unknown")
}
```

### The nil-interface gotcha

An interface holds *(type, value)*. An interface is `nil` only if *both* are nil. A non-nil interface wrapping a nil pointer is **not nil** — this is the #1 Go interface bug:

```go
func doThing() error {
    var p *MyError = nil
    return p              // BUG: returns a non-nil error wrapping a nil pointer!
}
// if doThing() != nil  → TRUE, even though the underlying pointer is nil
```

Best practice: keep interfaces small and define them where they're consumed, not where types are implemented. Return concrete types from constructors. Never return a typed nil as an interface — return a literal `nil`.

---

## 10. Errors — no exceptions

Go has **no exceptions** for ordinary error handling. Functions return errors as values, and you check them explicitly.

```go
f, err := os.Open("file.txt")
if err != nil {
    return fmt.Errorf("opening config: %w", err)   // %w wraps the error
}
defer f.Close()
```

- **`error` is just an interface:** `type error interface { Error() string }`. Any type with an `Error() string` method is an error.
- **The `if err != nil` pattern is everywhere.** Yes, it's verbose. Yes, it's intentional — errors are explicit, visible in the code, and impossible to silently ignore (an unused `err` is a compile error). No hidden control flow, no stack unwinding.
- **Wrap with `%w`** to build an error chain. Unwrap and inspect with:
  - `errors.Is(err, ErrNotFound)` — is this error (or anything it wraps) a specific sentinel?
  - `errors.As(err, &target)` — extract a specific error *type* from the chain.

  ```go
  var ErrNotFound = errors.New("not found")

  if errors.Is(err, ErrNotFound) {
      // handle the not-found case
  }
  ```

- **Custom error types** carry structured data:

  ```go
  type ValidationError struct {
      Field string
      Msg   string
  }
  func (e *ValidationError) Error() string {
      return fmt.Sprintf("%s: %s", e.Field, e.Msg)
  }
  ```

- **`panic`/`recover` are NOT exceptions.** `panic` is for unrecoverable, programmer-error situations (nil dereference, out-of-bounds, "this should never happen"). It unwinds the stack running deferred functions. `recover` (inside a `defer`) stops the unwinding. Use them at process boundaries (e.g., a server's top-level handler converting a panic into a 500), *never* as normal control flow. See §12.

Analogy: this is the opposite of C#'s `try/catch`. Errors are data you pass around, not control flow you throw. It trades brevity for explicitness — you always see exactly where errors can occur and how they're handled.

Best practice: handle or return every error; add context with `fmt.Errorf("...: %w", err)` as it propagates up. Define sentinel errors (`var ErrX = errors.New(...)`) for conditions callers branch on. Reserve `panic` for truly impossible states.

---

## 11. Slices, arrays, and maps

### Arrays — fixed size, rarely used directly

```go
var a [3]int = [3]int{1, 2, 3}   // length is part of the type: [3]int != [4]int
```

Arrays are value types (copied on assignment) and their length is fixed at compile time. You'll rarely use them directly — slices are what you reach for.

### Slices — the workhorse

```go
s := []int{1, 2, 3}              // slice literal
s = append(s, 4)                 // grow (may reallocate)
sub := s[1:3]                    // slice of a slice — shares backing array!
made := make([]int, 0, 10)       // len 0, capacity 10 (pre-allocated)
```

- A slice is a **3-word header**: pointer to a backing array, length, capacity. It's a *view* into an array — like `std::span`, but it can grow via `append`.
- **`append` may reallocate.** If capacity is exceeded, it allocates a new bigger array and copies. The return value may point to different memory — *always* write `s = append(s, x)`.
- **Slices share backing arrays.** `sub := s[1:3]` does not copy; mutating `sub[0]` mutates `s[1]`. This is a common aliasing bug. Use `slices.Clone` or `copy` when you need an independent copy.
- **`make([]T, len, cap)`** pre-allocates — use it when you know the size to avoid repeated reallocations (the perf-minded C++ instinct applies).
- The `slices` package (Go 1.21+) has `Sort`, `Contains`, `Index`, `Clone`, `Equal`, etc.

Analogy: slice ≈ `std::vector` semantics for growth + `std::span` semantics for sub-views, fused into one type. The shared-backing-array behavior has no direct C#/C++ analog — watch for it.

### Maps — hash tables

```go
m := map[string]int{"a": 1, "b": 2}
m["c"] = 3
v := m["x"]            // 0 if absent — zero value, NOT an error
v, ok := m["x"]        // comma-ok: ok is false if key absent
delete(m, "a")
made := make(map[string]int)   // empty, ready to use
```

- **A nil map can be read but not written** — writing to a nil map panics. Always `make` a map (or use a literal) before writing.
- **Iteration order is random** — by design. Sort the keys if you need order.
- **Reading a missing key returns the zero value, not an error.** Use the comma-ok form to distinguish "absent" from "present with zero value."
- Maps are reference-like: passing a map to a function lets the function mutate it.

Analogy: `map` ≈ C# `Dictionary` / C++ `unordered_map`, but with zero-value-on-miss and randomized iteration order as the notable differences.

Best practice: pre-size slices and maps with `make(..., cap)` when the size is known. Be deliberate about whether a sub-slice shares memory. Never assume map order.

---

## 12. defer, panic, recover

### defer

```go
func process() error {
    f, err := os.Open("x")
    if err != nil {
        return err
    }
    defer f.Close()          // runs when process() returns, no matter how

    mu.Lock()
    defer mu.Unlock()        // pairs the unlock with the lock visually
    // ... work ...
    return nil
}
```

- **`defer` schedules a call to run when the surrounding function returns** — on a normal return, an early return, or a panic. It's Go's RAII / `using` / `finally`.
- **LIFO order:** multiple defers run in reverse order, like stacked destructors.
- **Arguments are evaluated when `defer` is hit**, not when it runs — a classic gotcha:

  ```go
  i := 0
  defer fmt.Println(i)   // prints 0, even though...
  i = 5                  // ...i is 5 at return time
  ```
- Deferred closures *can* read/modify named return values — useful for wrapping errors on the way out.

Analogy: `defer f.Close()` is the explicit, statement-level version of C++ RAII destructors or C# `using`. You write the cleanup right next to the acquisition.

### panic / recover

```go
func safeHandler() {
    defer func() {
        if r := recover(); r != nil {
            log.Printf("recovered: %v", r)   // turn a panic into a logged error
        }
    }()
    riskyWork()
}
```

- **`panic`** stops normal flow, runs deferred functions up the stack, and crashes the program if not recovered. Triggered by runtime errors (nil deref, index out of range) or an explicit `panic(...)`.
- **`recover`** only works *inside a deferred function*. It stops the unwinding and returns the panic value.
- **This is not exception handling.** Use it only for: (a) truly unrecoverable programmer errors, (b) a top-level boundary (HTTP handler, goroutine root) that must not let one bad request kill the process. Normal errors use the `error` return value (§10).

Best practice: `defer` your cleanup immediately after acquiring a resource. Don't use panic/recover for control flow. Do put a recover at goroutine/request boundaries so one panic doesn't take down the server.

---

## 13. Composition over inheritance (embedding)

Go has **no inheritance** — no base classes, no `virtual`, no `override`. Reuse comes from **embedding** (composition) and interfaces.

```go
type Animal struct {
    Name string
}
func (a Animal) Speak() string { return a.Name + " makes a sound" }

type Dog struct {
    Animal          // embedded — no field name
    Breed string
}

d := Dog{Animal: Animal{Name: "Rex"}, Breed: "Lab"}
fmt.Println(d.Name)      // promoted field — d.Animal.Name
fmt.Println(d.Speak())   // promoted method
```

- **Embedding promotes the inner type's fields and methods** to the outer type. `d.Name` and `d.Speak()` work directly. It *looks* like inheritance but it's composition — `Dog` *has an* `Animal`, it is not a subtype.
- **No polymorphism through embedding.** `Dog` is not a `Animal` for type purposes; assignability comes from *interfaces*, not embedding. If `Animal` satisfies `Speaker`, so does `Dog` (because the method is promoted) — that's how you get polymorphic behavior.
- **No method overriding** in the OOP sense. If `Dog` defines its own `Speak()`, it *shadows* the embedded one (the outer wins at the outer level), but there's no virtual dispatch back into the base — `Animal`'s other methods still call `Animal`'s `Speak`, not `Dog`'s. There is no `base.Speak()` virtual chain.
- **Interface embedding** composes interfaces: `io.ReadWriter` is just `interface { Reader; Writer }`.

Analogy: this is closer to C++ composition / "has-a" with delegation than to inheritance. If you're reaching for a class hierarchy, stop — model the *behavior* with a small interface and embed concrete helpers for code reuse.

Best practice: favor small interfaces for polymorphism and embedding for code reuse. Don't try to recreate C# class hierarchies; you'll fight the language and lose.

---

## 14. Concurrency — goroutines and channels

Concurrency is Go's headline feature and its biggest departure from C++/C#. The model: **"Don't communicate by sharing memory; share memory by communicating."**

### Goroutines

```go
go doWork()              // launches doWork in a new goroutine, returns immediately

go func() {
    fmt.Println("in a goroutine")
}()
```

- A **goroutine** is a function running concurrently, multiplexed onto OS threads by the Go runtime scheduler. They're *cheap* — a few KB of stack, growing on demand. You can run hundreds of thousands. (Contrast: an OS thread is ~1MB; a C# `Thread` is heavy, though `Task`/`async` is the closer analogy.)
- The `go` keyword starts one. `main` returning kills all goroutines — you must coordinate (channels, `sync.WaitGroup`) to wait.

### Channels

```go
ch := make(chan int)         // unbuffered — send blocks until a receiver is ready
buf := make(chan int, 10)    // buffered — send blocks only when full

ch <- 42                     // send
v := <-ch                    // receive
v, ok := <-ch                // ok is false if channel is closed and drained
close(ch)                    // sender closes; receivers can drain remaining values

for v := range ch {          // receive until the channel is closed
    fmt.Println(v)
}
```

- Channels are **typed, thread-safe pipes** for passing values *and* synchronizing. They're the primary tool — not locks.
- **Unbuffered channels synchronize**: a send blocks until a receive happens (a rendezvous). Buffered channels decouple producer and consumer up to the buffer size.
- **Close from the sender side only.** Receiving from a closed channel returns the zero value with `ok == false`. Sending to a closed channel panics.

### select

```go
select {
case v := <-ch1:
    fmt.Println("from ch1:", v)
case ch2 <- 10:
    fmt.Println("sent to ch2")
case <-time.After(time.Second):
    fmt.Println("timeout")          // common pattern
default:
    fmt.Println("nothing ready")    // non-blocking
}
```

`select` waits on multiple channel operations — like a `switch` for channels. It's how you implement timeouts, cancellation, and fan-in/fan-out.

### context — cancellation and deadlines

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

select {
case <-ctx.Done():
    return ctx.Err()           // cancelled or timed out
case res := <-work:
    return res
}
```

`context.Context` propagates cancellation and deadlines across API and goroutine boundaries. By convention it's the *first* parameter of any function that does I/O or blocks: `func F(ctx context.Context, ...)`.

### When you do share memory: sync

The `sync` package has `Mutex`, `RWMutex`, `WaitGroup`, `Once`, and `atomic` for lock-based code when channels don't fit:

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func() {
        defer wg.Done()
        process(item)
    }()
}
wg.Wait()                       // block until all goroutines finish
```

- **Always run `go test -race`.** The built-in race detector finds data races — your C++ thread-sanitizer instincts apply, and here it's one flag.
- Rule of thumb: use **channels to pass ownership/coordinate**, use a **mutex to protect a small piece of shared state**. Don't overuse channels where a mutex is simpler.

Analogy: goroutines ≈ extremely cheap `Task`s with a built-in scheduler; channels ≈ a typed, blocking `BlockingCollection`/pipe that also synchronizes. `context` ≈ `CancellationToken`, but threaded through explicitly as the first argument.

Best practice: pass `ctx` first, always. Prefer channels for coordination and mutexes for guarding state. Never start a goroutine without knowing how it ends. Test with `-race` constantly.

---

## 15. Generics

Generics arrived in Go 1.18 — deliberately limited compared to C++ templates or C# generics.

```go
func Max[T cmp.Ordered](a, b T) T {     // T constrained to ordered types
    if a > b {
        return a
    }
    return b
}

type Stack[T any] struct {              // generic type
    items []T
}
func (s *Stack[T]) Push(v T) { s.items = append(s.items, v) }

Max(3, 5)            // T inferred as int
Max("a", "b")        // T inferred as string
```

- **Type parameters** go in `[brackets]`. **Constraints** are interfaces describing what operations `T` supports. `any` means no constraint; `comparable` allows `==`; `cmp.Ordered` allows `<`, `>`.
- **Constraints can be type sets:** `interface { ~int | ~float64 }` means "any type whose underlying type is int or float64." The `~` means "underlying type."
- **Much narrower than C++ templates.** No template metaprogramming, no specialization, no non-type parameters, no SFINAE. Generics exist to write type-safe containers and algorithms (`Map`, `Filter`, `slices.Sort`), not for compile-time computation.
- **Closer to C# generics with constraints** than to C++ templates — but still more restrictive (no `where T : new()`, no covariance).

Best practice: reach for generics for genuinely type-agnostic data structures and utility functions (the `slices` and `maps` std packages are the model). Don't genericize prematurely — a concrete type or an interface is often clearer.

---

## 16. Visibility, naming, and idioms

- **Capitalization is access control.** `ExportedName` is public (visible outside the package); `unexportedName` is package-private. This applies to types, functions, methods, fields, constants, and variables. There is no `public`/`private`/`protected`. (`internal/` packages add a module-level boundary — see proj-structure.md §5.)
- **Naming conventions:**
  - `MixedCaps` / `mixedCaps`, never `snake_case`.
  - Short names for short scopes: `i`, `r`, `buf`, `ctx`, `err`. Longer names for package-level identifiers.
  - **No `Get` prefix** on getters: `user.Name()`, not `user.GetName()`. Setters do use `Set`: `user.SetName(...)`.
  - Single-method interfaces are named with an `-er` suffix: `Reader`, `Writer`, `Stringer`, `Closer`.
  - Package names are short, lowercase, no underscores — and the call site reads `pkg.Thing`, so don't stutter (`http.HTTPServer` → `http.Server`).
- **`iota` for enums** (Go has no real `enum` type):

  ```go
  type Weekday int
  const (
      Sunday Weekday = iota   // 0
      Monday                  // 1
      Tuesday                 // 2
      // ...
  )
  ```
  Add a `String()` method (or generate one with `stringer`) so the enum prints nicely. This is the C# `enum` replacement.
- **Doc comments** are plain comments immediately above an exported symbol, starting with the symbol's name: `// User represents ...`. No Doxygen, no XML-doc. `go doc` and pkg.go.dev render them.
- **One canonical format.** `gofmt` settles all whitespace/brace debates. Tabs for indentation, no configurable style. Don't argue, just run it (your IDE does on save).

Best practice: let casing express your API surface — export the minimum. Follow the naming idioms exactly; Go code is remarkably uniform and reviewers expect it.

---

## 17. Quick reference: C++/C# → Go

| Concept | C++ / C# | Go |
|---|---|---|
| Visibility | `public`/`private` keywords | capitalized = exported |
| Inheritance | base classes, `virtual` | embedding + interfaces (composition) |
| Interfaces | `implements` / `: IFoo` | implicit (structural) — no declaration |
| Error handling | exceptions, `try/catch` | `(value, error)` returns + `if err != nil` |
| Null | `null` / `nullptr` | `nil`; every type has a zero value |
| Constructors | `ctor` / `new T()` | `New...` funcs; useful zero value |
| Generics | templates / `T<...>` | type params `[T constraint]` (limited) |
| Threads | `std::thread` / `Task` | goroutines (`go f()`) |
| Locks/sync | mutex / channels rare | channels first, `sync.Mutex` for state |
| Cancellation | `CancellationToken` | `context.Context` (first arg) |
| RAII / `using` / `finally` | destructors / `using` | `defer` |
| Enums | `enum` | `const` + `iota` + `String()` |
| Method dispatch | virtual tables | interfaces; embedding shadows, no override |
| Memory mgmt | manual / GC | GC + escape analysis, no `delete` |
| Ternary `?:` | yes | no — use `if` |
| `while` loop | yes | `for cond {}` |
| Overloading | yes | no — distinct names / variadic |
| Default args | yes | no — variadic / functional options |
| Pointer arithmetic | yes (C++) | no |
| Implicit numeric conversion | yes | no — always explicit |
| String | mutable / UTF-16 (C#) | immutable, UTF-8, byte-indexed |
| Container growth | `vector` / `List` | `slice` + `append` (watch shared backing) |
| Hash map | `unordered_map` / `Dictionary` | `map` (zero on miss, random order) |

---

## Summary: the ten things that trip up C++/C# developers

1. **No exceptions** — errors are values you check with `if err != nil`.
2. **Interfaces are implicit** — no `implements`; define them in the consumer, keep them small.
3. **No inheritance** — compose with embedding, polymorph with interfaces.
4. **Zero values everywhere** — no nulls for value types; make the zero value useful instead of writing constructors.
5. **Value vs pointer receivers** — the per-method copy/reference decision is yours, and it matters.
6. **Slices share backing arrays** — sub-slicing aliases memory; `append` may reallocate.
7. **`defer` for cleanup** — it's your RAII/`using`/`finally`.
8. **Goroutines + channels + context** — cheap concurrency, coordinate by communicating, pass `ctx` first.
9. **Capitalization is visibility**, and unused variables/imports are compile errors.
10. **No ternary, no `while`, no overloading, no default args, no implicit conversions** — the language is small on purpose; write it out and run `gofmt`.
