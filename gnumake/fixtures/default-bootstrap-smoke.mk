.RECIPEPREFIX := >
all: serial parallel
serial:
>@printf 'serial\n' > serial.out
parallel: a b
>@cat a.out b.out > parallel.out
a:
>@printf 'a\n' > a.out
b:
>@printf 'b\n' > b.out
