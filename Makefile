.SUFFIXES:

prueba: y.tab.c
	gcc -o trad y.tab.c

y.tab.c: p3.y lex.yy.c
	yacc -d -v -o y.tab.c p3.y
	#bison -d -v -o y.tab.c p3.y

lex.yy.c: lexico.l
	flex lexico.l

limpia:
	rm -f trad y.tab.c lex.yy.c y.output y.tab.h

todo:
	make --no-print-directory limpia
	make --no-print-directory prueba

# Test
test_programita: todo
	./trad < ./prueba.prog

test_sintactico: todo
	./trad < ./pruebaerrores.prog
