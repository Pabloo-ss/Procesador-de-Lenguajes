%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

FILE* yyout;

void yyerror( const char * msg );

#define YYERROR_VERBOSE

#define NONEDIM -1

// Esto elimina un Warning, no debería cambiar nada más.
int yylex();

char msgError[256];

/************************/
/* ESTRUCTURA DE LA TS */
/***********************/

typedef enum {
      marca, /* marca comienzo bloque */
      funcion, /* si es subprograma */
      variable, /* si es variable */
      parametro_formal, /* si es parametro formal */
      descriptor,
} tEntrada ;

// Para bucles if
typedef struct {
  char* etiquetaEntrada;
  char* etiquetaSalida;
  char* etiquetaElse;
} DescriptorDeInstrControl;

//Si tEntrada es funcion, variable, o parametro-formal; indica el tipo

typedef enum {
      entero,
      caracter,
      real,
      booleano,
      listaEntero,
      listaReal,
      listaCaracter,
      listaBooleano,
      error,
      cadena
} tSimbolo ;// tSimbolo indica el tipo de la variable

typedef struct {
      tEntrada entrada ;
      char *nombre ;
      tSimbolo tipoDato ;
      unsigned int parametros ;
      unsigned int dimension ;
      DescriptorDeInstrControl* descriptor; // Descriptor de control (bucles IF - intermedio)
      // int TamDim1 ; para las listas tambien no ??
} entradaTS ;
//Se usa para formar


#define MAX_TS 500 //tamaño maximo de la pila

long int TOPE=0 ; /* Tope de la pila */
unsigned int Subprog = 0 ; /* Indicador de comienzo de bloque de un Subprog */
int numArgs[2] = {0,0};
int numArgs_llevados =0;
int dentro_expresion = 0;
int error_args=0;
entradaTS TS[MAX_TS] ; /* Pila de la tabla de símbolos */
tSimbolo tipoTmp; // Tipo auxiliar para declaración de variables

typedef struct {
      int atrib ; /* Atributo del símbolo (si tiene) */
      char *  lexema ; /* Nombre del lexema */
      tSimbolo tipo ; /* Tipo del símbolo */
      char codigo[500];
      char valor[100];
} atributos ;


#define YYSTYPE atributos

/* *Inicio funciones auxiliares */

char* tipoAString(tSimbolo tipo_dato) {
  switch (tipo_dato) {
    case real:
      return "float";
    case entero:
      return "int";
    case booleano:
      return "bool";
    case caracter:
      return "char";
    case listaReal:
      return "list float";
    case listaEntero:
      return "list int";
    case listaCaracter:
      return "list char";
    case listaBooleano:
      return "list bool";
    case error:
      return "error";
    case cadena:
      return "cadena";
    default:
      fprintf(stderr, "Error en tipoAString(), no se conoce el tipo dato%i\n",tipo_dato);
      exit(EXIT_FAILURE);
  }
}

tSimbolo aTipoLista(tSimbolo ts){
  switch (ts) {
    case real:
      return listaReal;
    case entero:
      return listaEntero;
    case booleano:
      return listaBooleano;
    case caracter:
      return listaCaracter;
    case error:
      return error;
    default:
      fprintf(stderr, "Error en aTipoLista(), no se conoce el tipo dato\n");
      exit(EXIT_FAILURE);
  }
}

tSimbolo listaATipo(tSimbolo ts){
  switch (ts) {
    case listaReal:
      return real;
    case listaEntero:
      return entero;
    case listaBooleano:
      return booleano;
    case listaCaracter:
      return caracter;
    case error:
      return error;
    default:
      fprintf(stderr, "Error en listaATipo(), no se conoce el tipo dato (%s)\n", tipoAString(ts));
      exit(EXIT_FAILURE);
  }
}

int esLista(tSimbolo tipo_dato){
  return tipo_dato == listaEntero || tipo_dato == listaReal || tipo_dato == listaBooleano || tipo_dato == listaCaracter;
}


int esEntero(tSimbolo tipo_dato){
  return tipo_dato == entero;
}


tSimbolo tipoCons(char* cons){
  tSimbolo a = error;

  switch(*cons){
      case 'v': a = booleano; break;
      case 'f': a = booleano; break;
      case '\'': a = caracter; break;
      default: a = entero;
  }

  
  for(int i = 0; i != '\n'; i++){
    if(*(cons + i) == '.'){
      a = real;

    }   
  }
  

  return a;
}

void imprimir() {
  for (int i = 0; i <= TOPE; ++i) {
    printf("[%i]: ", i);
    switch(TS[i].entrada) { 
      case variable:
        printf("Variable %s, tipo: %s\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato));
        break;
      case funcion:
        printf("Funcion %s, tipo: %s, nº parametros: %i\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato), TS[i].parametros);
        break;
      case marca:
        printf("Marca\n");
        break;
      case parametro_formal:
        printf("Parametro formal %s, tipo: %s\n", TS[i].nombre,
            tipoAString(TS[i].tipoDato));
        break;
      default:
        fprintf(stderr, "Error en imprimir(), no debería salir\n");
        exit(EXIT_FAILURE);
    }
    if(i==TOPE)printf("-------------------------------------------------\n");
  }
}

void idRepetida(char* id) {
  // Miramos si id estaba declarado después de la última marca
  int repetida = 0;
  for (int i = TOPE; !repetida && TS[i].entrada != marca; --i) {
    if (TS[i].entrada != parametro_formal && !strcmp(TS[i].nombre, id)) {  
      sprintf(msgError, "ERROR SEMANTICO: identificador %s ya declarado\n", id);
      yyerror(msgError);
      repetida = 1;
    }
  }
}

void insertarEntrada(tEntrada te, char* nombre, tSimbolo tipo_dato, int nParam, int dimension, DescriptorDeInstrControl* descp) {
  // Hacemos la entrada
  entradaTS entrada = {
    te,
    strdup(nombre),
    tipo_dato,
    nParam,
    dimension,
    descp
  };

  // Si la tabla está llena da error
  if (TOPE + 1 >= MAX_TS) {
    sprintf(msgError, "ERROR SEMANTICO: La tabla de símbolos está llena\n");
    yyerror(msgError);
  }
  // Aumentamos el TOPE
  ++TOPE;
  // Añadimos la nueva entrada
  TS[TOPE] = entrada;
}

// Busca una entrada en la TS con el id especificado en el ámbito del programa
// actual. Si no lo encuentra, devuelve -1. No gestiona errores!
int buscarEntrada(char* id) {
  int i = TOPE;
  while(i > 0){
    if(!(TS[i].entrada == parametro_formal || strcmp(id, TS[i].nombre)))
      break;
    --i;
  }

  if (i <= 0) {
    sprintf(msgError, "ERROR SEMANTICO: identificador %s no declarado\n", id);
    yyerror(msgError);
  }
  return i;
}

int numeroArg(char * id){
  int i = TOPE;
  while(i > 0){
    if(!(TS[i].entrada == parametro_formal || strcmp(id, TS[i].nombre)))
      break;
    --i;
  }
  
  return TS[i].parametros;
}

/* *Fin funciones auxiliares */

/* *Lista de funciones y procedimientos para manejo de la TS */

void insertarMarca() {
  // Metemos la marca
  insertarEntrada(marca, " ", -1, -1, -1, NULL);
  // Si es subprograma añadimos las variables al bloque
  if (Subprog) {
    for (int i = TOPE - 1; TS[i].entrada != funcion; --i) {
      insertarEntrada(variable, TS[i].nombre, TS[i].tipoDato, -1, -1, NULL); 
    }
    Subprog = 0;
  }
}

void vaciarEntradas() {
  // Hasta la última marca borramos todo
  while (TS[TOPE].entrada != marca) --TOPE;
  // Elimina la última marca
  --TOPE;
  
}

void insertarVariable(char* id, int dimension) {
  // Comprobamos que no esté repetida la id
  idRepetida(id);
  insertarEntrada(variable, id, tipoTmp, -1, dimension, NULL);   
}

void insertarFuncion(tSimbolo tipoDato, char* id) {
  // Comprobamos que el id no esté usado ya
  idRepetida(id);
  insertarEntrada(funcion, id, tipoDato, 0, -1, NULL);
}

void insertarParametro(tSimbolo tipoDato, char* id) {
  // Comprobamos que no haya parámetros con nombres repetidos
  // Además guardamos el índice de la función
  int i;
  int parametroRepetido = 0;
  for (i = TOPE; !parametroRepetido && TS[i].entrada != funcion; --i) {
    if (!strcmp(TS[i].nombre, id)) {
      sprintf(msgError, "ERROR SEMANTICO: identificador del parámetro %s ya declarado\n", id);
      yyerror(msgError);
      parametroRepetido = 1;
    
    }
  }
  // Añadimos la entrada
  insertarEntrada(parametro_formal, id, tipoDato, -1, NONEDIM, NULL); // ********** una vez mas de dnd sacar la dimension ************
  // Actualizamos el nº de parámetros de la función
  ++TS[i].parametros;
}

void insertarDescriptor(char* etqEntrada, char* etqSalida, char* etqElse) {
  DescriptorDeInstrControl* descp = (DescriptorDeInstrControl*) malloc(sizeof(DescriptorDeInstrControl));
  descp->etiquetaEntrada = strdup(etqEntrada);
  descp->etiquetaSalida = strdup(etqSalida);
  descp->etiquetaElse = strdup(etqElse);
  insertarEntrada(descriptor, " ", -1, -1, -1, descp);
}

tSimbolo buscarID(char* id) {
  int i = buscarEntrada(id);

  if (i < 0)
    return error;
  return TS[i].tipoDato;
}

void comprobarAsignacion(char* id, tSimbolo ts) {
  int i = buscarEntrada(id);
  
  if (i >= 0) {
    if (TS[i].entrada != variable) {
      sprintf(msgError, "ERROR SEMANTICO: se intenta asignar a %s, y no es una variable\n", id);
      yyerror(msgError);
    } else {
      if (esLista(TS[i].tipoDato)){
        if (ts == error || ts != listaATipo(TS[i].tipoDato)) {
          sprintf(msgError, "ERROR SEMANTICO: asignación incorrecta, %s es tipo %s y se obtuvo %s\n", id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }else{
        if (ts == error || ts != TS[i].tipoDato) {
          sprintf(msgError, "ERROR SEMANTICO2: asignación incorrecta, %s es tipo %s y se obtuvo %s\n",
           id, tipoAString(TS[i].tipoDato), tipoAString(ts));
          yyerror(msgError);
        }
      }
    }
    
  }
}

void isBooleana(tSimbolo ts) {
  if (ts == error || ts != booleano) {
    sprintf(msgError, "ERROR SEMANTICO: condición no es de tipo booleano, se tiene tipo %s", tipoAString(ts));
    yyerror(msgError);
  }
}


tSimbolo opBinario(tSimbolo ts1, int atr, tSimbolo ts2) { 
  if (ts1 == error || ts2 == error) return error; 

  if(esLista(ts1))
    ts1 = listaATipo(ts1);
  if(esLista(ts2))
    ts2 = listaATipo(ts2);
  
  switch(atr){ 
    case 0: // * 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
        sprintf(msgError, "ERROR SEMANTICO: operador * no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error; 
      } 
    break; 
    case 1: // / 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
      sprintf(msgError, "ERROR SEMANTICO: operador / no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
      yyerror(msgError); 
      return error; 
      } 
    break; 
    case 2: // or 
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador or no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 3: // and 
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador and no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 4:// xor  
      if(!(ts1 == booleano && ts2 == booleano)){
        sprintf(msgError, "ERROR SEMANTICO: operador xor no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 5://  == 
      if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real)|| (ts1 == booleano && ts2 == booleano)|| (ts1 == caracter && ts2 == caracter)) ){
        sprintf(msgError, "ERROR SEMANTICO: operador == no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 6:// < 
      if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador < no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 7:// > 
     if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador > no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break; 
    case 8: // + 
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
      sprintf(msgError, "ERROR SEMANTICO: operador + no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
      yyerror(msgError); 
      return error; 
      } 
    break;
    case 9:// <=
     if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador >= no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break;
    case 10:// >= 
     if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador <= no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break;   
    case 11:// >= 
     if(!((ts1 == entero && ts2 == entero)|| (ts1 == real && ts2 == real))){
        sprintf(msgError, "ERROR SEMANTICO: operador != no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
        yyerror(msgError); 
        return error;
      }
      return booleano;
    break;  
    case 12: // -
      if(ts1 == entero && ts2 == entero) return entero; 
      else if(ts1 == real && ts2 == real) return real; 
      else{ 
      sprintf(msgError, "ERROR SEMANTICO: operador - no aplicable a los tipos %s y %s\n",tipoAString(ts1), tipoAString(ts2)); 
      yyerror(msgError); 
      return error; 
      } 
    break;
  } 
}

void menosUnarioAplicable(tSimbolo ts){
  if(!(ts == entero || ts == real)){
    sprintf(msgError, "ERROR SEMANTICO: el operador - no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void opUnarioAplicable(tSimbolo ts){
  if(ts != booleano){
    sprintf(msgError, "ERROR SEMANTICO: el operador not no es aplicable al tipo %s\n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDimen(tSimbolo ts){
  if(!esEntero(ts)){
    sprintf(msgError, "ERROR SEMANTICO: el tipo %s no es válido como dimensión \n", tipoAString(ts));
    yyerror(msgError);
  }
}

void comprobarDevolver(tSimbolo ts){
  int i = TOPE;
  int marcaEncontrada = 0;
  int funcionEncontrada = 0;
  
  while (i >1 && (TS[i].entrada != funcion || TS[i].entrada == marca )) {
    
    --i;
  }
  
  
  if (i <= 0) {
    sprintf(msgError, "ERROR SEMANTICO: return no asignado a ninguna función, e i = %i \n",i);
    yyerror(msgError);
  } else if (ts != error && ts != TS[i].tipoDato && Subprog == 1) {
    sprintf(msgError, "ERROR SEMANTICO: return devuelve tipo %s, y función es de tipo %s\n",  tipoAString(ts), tipoAString(TS[i].tipoDato));
    yyerror(msgError);
  }
}

void comprobarArg(tSimbolo ts){
  
  if(TS[numArgs[1] + numArgs_llevados+1].tipoDato != ts)
    error_args=1;
  numArgs_llevados++;
}

void erroresArgs(){
  //numArgs_llevados++;
  if(numArgs[0]<numArgs_llevados ){
    sprintf(msgError, "ERROR SEMANTICO: Demasiados argumentos introducidos ");
    yyerror(msgError);

  }else if(numArgs[0]>numArgs_llevados){
    sprintf(msgError, "ERROR SEMANTICO: Pocos argumentos introducidos ");
    yyerror(msgError);
  }else if(numArgs[0]==numArgs_llevados && !error_args){

  }
  else if (error_args){
    sprintf(msgError, "ERROR SEMANTICO: tipo no se corresponde con los argumentos de la funcion \n");
    yyerror(msgError);
    }

  numArgs_llevados=0;
  error_args = 0;
}

tSimbolo tipoOp(tSimbolo ts, char * op) {
  if (!strcmp(op, "+") || !strcmp(op, "-") || !strcmp(op, "*") || !strcmp(op, "/"))
    return ts;
    

  if (!strcmp(op, "not") || !strcmp(op, "and") || !strcmp(op, "xor") || !strcmp(op, "or") || !strcmp(op, ">") || !strcmp(op, "<") || !strcmp(op, "==")
  || !strcmp(op, "<=")|| !strcmp(op, ">=")|| !strcmp(op, "!="))
    return booleano;

}

/* * Fin de funciones y procedimientos para manejo de la TS */

// *******  Generación código intermedio ******

int hayError = 0;
int deep = 0;
int dirtyFun = 0;
FILE * fMain;
FILE * fFunc;


#define addTab() { for (int i = 0; i < deep - (yyout != fMain); ++i) fprintf(yyout, "\t"); }
#define gen(f_, ...) { if (!hayError) {addTab(); fprintf(yyout, f_, ##__VA_ARGS__); fflush(yyout);} }

char* temporal() {
  static int indice = 1;
  char* temp = malloc(sizeof(char) * 10);
  sprintf(temp, "temp%i", indice++);
  return temp;
}

char* etiqueta() {
  static int indice = 1;
  char* etiqueta = malloc(sizeof(char) * 14);
  sprintf(etiqueta, "etiqueta%i", indice++);
  return etiqueta;
}

char* tipoIntermedio(tSimbolo ts) {
  if (esLista(ts))
    return "Lista";
  else if (ts == booleano)
    return "int";
  else 
    
    return tipoAString(ts);
}

char* leerOp(tSimbolo ts1, char* exp1, char* op, char* exp2, tSimbolo ts2) { //crea la variable temporal en gen()
  char* etiqueta = temporal();
  tSimbolo tsPrimario = ts1;
  char* expPrimaria = exp1;
  char* expSecundaria = exp2;
  /*if (esLista(ts2) && (!strcmp("+", op) || !strcmp("*", op))) {
    tsPrimario = ts2;
    expPrimaria = exp2;
    expSecundaria = exp1;
  }*/
  
  gen("%s %s;\n", tipoIntermedio(tipoOp(tsPrimario, op)), etiqueta); //crea la variable tempor
  gen("%s = %s %s %s; \n", etiqueta, exp1, op, exp2 )

  
  return etiqueta;
}


char* leerCte(char* cte, tSimbolo ts) {
  if (ts == booleano) {
    if (!strcmp("verdadero", cte))
      return "1";
    else
      return "0";
  }
  return cte;
}


char* tipoImprimir(tSimbolo tipo) {
  if (tipo == entero)
    return "%d";
  else if (tipo == real)
    return "%f";
  else if (esLista(tipo) || tipo == booleano || tipo == cadena)
    return "%s";
  else if (tipo == caracter)
    return "%c";
  else {
    if (!hayError) {
      sprintf(msgError, "ERROR INTERMEDIO: tipoImprimir() tipo no válido.\n");
      yyerror(msgError);
      exit(EXIT_FAILURE);
    }
  }
}



#define YYSTYPE atributos /* Cada símbolo tiene una estructura de tipo atributos */

%}

/*
Lista Tokens
*/
%start programa
%token PARDER PARIZQ
%token CORDER CORIZQ
%token LLAVEDER LLAVEIZQ
%token CONDFOR CONDWHILE
%token CONDIF CONDELSE
%token MENOS OPERADORBIN OPERADORUNARIO
%token TIPO 
%token LISTA
%token CONS IDEN 
%token PYC COMA
%token ASIG
%token ENTRADA SALIDA
%token CADENA
%token PRINCIPAL DEVOLVER
/*
Lista Precedencias
*/
%left OPERADORBIN MENOS
%right OPERADORUNARIO
%right CONDFOR
%right SALIDA
%right ENTRADA
%left PARDER
%right PARIZQ
%left CORDER
%left CORIZQ
%left LLAVEDER
%right LLAVEIZQ



%%
programa : PRINCIPAL {
              gen("#include <stdlib.h>\n");
              gen("#include <stdio.h>\n");
              gen("#include \"dec_fun.h\"\n\n");
              gen("int main()\n");
              ++deep;
            }
            inicio_de_bloque {insertarMarca(); }

inicio_de_bloque : LLAVEIZQ {gen("{\n");} bloque  

bloque :  declar_de_fun bloque
        | sentencia bloque 
        | sentencia_return LLAVEDER  {vaciarEntradas(); Subprog = 0;gen("}\n"); dirtyFun--;--deep;if(dirtyFun == 0) yyout = fMain;}
        ;
    


declar_de_variable_locales :  TIPO  declaracion_v PYC    {gen("%s %s;\n", tipoIntermedio(tipoTmp), $2.codigo);}           
		| error IDEN
		| error PYC {yyerrok;}
		;
                
declaracion_v :   IDEN   {tipoTmp = $0.atrib; insertarVariable($1.lexema, NONEDIM); strcpy($$.codigo, $1.lexema);}
                | IDEN COMA declaracion_v  {tipoTmp = $0.atrib;insertarVariable($1.lexema, NONEDIM); sprintf($$.codigo, "%s, %s", $1.lexema, $3.codigo);}
                | IDEN ASIG expresion     {tipoTmp = $0.atrib; insertarVariable($1.lexema, NONEDIM); sprintf($$.codigo, "%s = %s", $1.lexema, $3.codigo);}
                ;

declar_de_fun : TIPO IDEN PARIZQ {insertarFuncion($1.atrib, $2.lexema); Subprog = 1;yyout = fFunc; dirtyFun++;gen("%s %s (",tipoIntermedio($1.atrib), $3.lexema );} argumentos {insertarMarca();gen("%s)", $5.codigo);} PARDER inicio_de_bloque 
                ;
llamada_func : IDEN PARIZQ {numArgs[0] = numeroArg($1.lexema);numArgs[1] = buscarEntrada($1.lexema);} argumentosLlamada PARDER   {erroresArgs(); sprintf($$.codigo, "%s(%s)", $1.lexema ,$4.codigo);$$.tipo=buscarID($1.lexema);}

sentencias :  sentencias  sentencia 
            | 
            ;

sentencia : sentencia_asignacion 
            | sentencia_if
            | sentencia_while
            | sentencia_entrada
            | sentencia_salida
            | llamada_func PYC
            | sentencia_for
            | tipo_variable_complejo
            | sentencia_return
            | declar_de_variable_locales
            ;



sentencia_asignacion : IDEN ASIG {gen("\n{\n"); ++deep; } expresion PYC                     {--deep;comprobarAsignacion($1.lexema, $4.tipo);gen("%s = %s;\n}\n", $1.lexema, $4.codigo);}
                      | iden_lista ASIG {gen("\n{\n"); ++deep; } expresion PYC                 {--deep;comprobarAsignacion($1.lexema, $3.tipo);}
                      ;                                            


sentencia_if : CONDIF { insertarDescriptor("", etiqueta(), etiqueta());}
              expresion {
                isBooleana($3.tipo); 
                gen("if (!%s) goto %s;\n", $3.codigo, TS[TOPE].descriptor->etiquetaElse);
                gen("{\n"); 
                ++deep;}
              LLAVEIZQ sentencias {
                 --deep; 
                 gen("}\n");
                 DescriptorDeInstrControl* ds = TS[TOPE].descriptor; 
                 gen("goto %s;\n\n", ds->etiquetaSalida);
                 gen("%s:", ds->etiquetaElse);}
              LLAVEDER  bloque_else {
                    gen("\n");
                    gen("%s: {} \n", TS[TOPE].descriptor->etiquetaSalida);
                    --TOPE;
                  };                                        
bloque_else : CONDELSE LLAVEIZQ{ gen("\n"); gen("{\n"); ++deep; }
                sentencias { --deep; gen("}\n"); }
                LLAVEDER
            | { int aux = deep; deep = 0; gen(" {}\n"); deep = aux; } ;
;

/************* WHILE *****************/

sentencia_while : CONDWHILE PARIZQ {
                      insertarDescriptor(etiqueta(), etiqueta(), "");
                      gen("%s:\n", TS[TOPE].descriptor->etiquetaEntrada);
                      gen("{\n");
                      ++deep;
                      gen("{\n");
                      ++deep;
                    }
                    expresion {
                      isBooleana($4.tipo);
                      gen("\n");
                      gen("if (!%s) goto %s;\n", $4.lexema, TS[TOPE].descriptor->etiquetaSalida);
                      --deep;
                      gen("}\n\n");
                    }
                    PARDER LLAVEIZQ sentencias 
                    {
                      gen("goto %s;\n\n", TS[TOPE-1].descriptor->etiquetaEntrada);
                      --deep;
                      gen("}\n");
                      gen("%s: {}\n", TS[TOPE-1].descriptor->etiquetaSalida);
                      --TOPE;
                    } LLAVEDER  {}




/************* ENTRADA *****************/
sentencia_entrada : ENTRADA PARIZQ IDEN PARDER PYC          {tSimbolo td = buscarID($3.lexema);
                                                              if (td == booleano) {
                                                              gen("char aux[32];\n");
                                                              gen("scanf(\"%s\", aux);\n", "%s");
                                                              gen("%s = aInt(aux);\n", $3.lexema);
                                                              } else {
                                                              gen("scanf(\"%s\", &%s);\n", tipoImprimir(td), $3.lexema);
                                                              }
                                                            } ;
                                                            
 

sentencia_for : CONDFOR PARIZQ  sentencia_asignacion PYC expresion PYC sentencia_asignacion PARDER LLAVEIZQ sentencias LLAVEDER   {isBooleana($5.tipo);} 

/************* RETURN *****************/

sentencia_return : DEVOLVER IDEN PYC                {$2.tipo = buscarID($2.lexema); comprobarDevolver($2.tipo); gen("return %s;\n", $2.lexema);}
                | DEVOLVER CONS PYC                 {$2.tipo = tipoCons($2.lexema); comprobarDevolver($2.tipo); gen("return %s;\n", $2.lexema);}
                ;


/************* SALIDA *****************/

sentencia_salida : SALIDA PARIZQ lista_salida PARDER PYC { gen("printf(\"\\n\");\n"); };            

lista_salida : lista_salida COMA expresion_cout
            | expresion_cout
            ;

expresion_cout: cadena_expresion { gen("printf(\"%s \", %s);\n", tipoImprimir($1.tipo), $1.lexema); gen("fflush(stdout);\n"); } ;

cadena_expresion : expresion {
                    if ($1.tipo == booleano) {
                      $$.lexema = malloc(sizeof(char) * (8 + strlen($1.lexema)));
                      sprintf($$.lexema, "aBool(%s)", $1.lexema);
                    } else
                      strcpy($$.lexema, $1.lexema);
                    $$.tipo = $1.tipo;
                  }
                | CADENA { strcpy($$.lexema, $1.lexema); $$.tipo = 9;}
                ;

argumentos : TIPO IDEN COMA argumentos                                {insertarParametro($1.atrib, $2.lexema);sprintf($$.codigo, "%s %s, %s", tipoIntermedio($1.atrib), $2.lexema, $4.codigo);}
            | TIPO IDEN                                               {insertarParametro($1.atrib, $2.lexema);sprintf($$.codigo, "%s %s", tipoIntermedio($1.atrib), $2.lexema);}
            | error
            ;
          
argumentosLlamada : expresion COMA argumentosLlamada                  {comprobarArg($1.tipo);sprintf($$.codigo, "%s, %s", $1.codigo, $3.codigo);}
            | expresion                                               {comprobarArg($1.tipo);sprintf($$.codigo, "%s", $1.codigo);}
            | 
            ;


expresion    : expresion OPERADORBIN expresion                        {$$.tipo = opBinario($1.tipo, $2.atrib, $3.tipo); strcpy($$.codigo, leerOp($1.tipo,$1.lexema,$2.lexema,$3.lexema,$3.tipo)); strcpy($$.lexema, $$.codigo);}
            | IDEN                                                    {$$.tipo = buscarID($1.lexema); strcpy($$.codigo, $1.lexema);} 
            | CONS                                                    {$$.tipo = tipoCons($1.lexema); strcpy($$.codigo, leerCte($1.lexema, $1.tipo));}
            | MENOS CONS                                              {$$.tipo = tipoCons($2.lexema); menosUnarioAplicable($2.tipo);strcpy($$.codigo, leerCte($1.lexema, $1.tipo));}
            | PARIZQ expresion PARDER                                 {strcpy($$.codigo, $2.codigo); $$.tipo = $2.tipo;}
            | OPERADORUNARIO expresion                                {opUnarioAplicable($2.tipo);}
            | expresion MENOS expresion                               {$$.tipo = opBinario($1.tipo, $2.atrib, $3.tipo); strcpy($$.codigo, leerOp($1.tipo,$1.lexema,$2.lexema,$3.lexema,$3.tipo)); strcpy($$.lexema, $$.codigo);}
            | llamada_func                                            {strcpy($$.codigo, $1.codigo); $$.tipo = $1.tipo;}
            | iden_lista
            | error
            ;

tipo_variable_complejo : TIPO LISTA CORIZQ CONS CORDER IDEN ASIG CORIZQ decl_tipo_comp CORDER PYC   {comprobarDimen(tipoCons($4.lexema));tipoTmp = aTipoLista($1.atrib); insertarVariable($6.lexema, atoi($4.lexema)); comprobarAsignacion($6.lexema, $9.tipo);}

                                                                                                      
iden_lista: IDEN CORIZQ CONS CORDER  {$$.tipo=aTipoLista($1.tipo);}



decl_tipo_comp : CONS COMA decl_tipo_comp                         {$$.tipo = tipoCons($1.lexema);}
                  | CONS                                          {$$.tipo = tipoCons($1.lexema);}
                  ; 



%%

#include "lex.yy.c"

void yyerror(const char *msg){
  fprintf(stderr, "[Linea %d]: %s\n", yylineno, msg);
}

int main(){
  fMain = fopen("prog.c", "w");
  fFunc = fopen("dec_fun.h", "w");

  yyout = fMain ;
  yyparse();

  fclose(fMain);
  fclose(fFunc);

  return 0;
}