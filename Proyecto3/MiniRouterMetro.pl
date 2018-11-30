%Programa para calcular la ruta optima entre dos estaciones del metro
% de la Ciudad de Mexico utilizando razonamiento basado en
% casos y basado en modelos (mapa jerarquizado) aplicando el algoritmo
% de busqueda A*.
% Autores: Amanda Velasco CU: 154415 Email: am_tuti@hotmail.com
%          Octavio Ordaz  CU: 158525 Email: octavio.ordaz13@gmail.com
% Fecha: 4 de diciembre de 2018

%-----------------------------Predicados Dinamicos--------------------------------
/*
Los siguientes predicados de la base de conocimientos seran modificados durante
tiempo de ejecucion para cargar datos y casos y para A*:
*/
:-dynamic conexion/5.
:-dynamic caso/3.
%---------------------------------------------------------------------------------

%----------------------------Funcionalidad Auxiliar-------------------------------
%Incluye archivo de funciones comunes
:-['Auxiliares.pl'].

%Incluye archivo de A*
:-['grafoMetro_Final.pl'].

% Carga los datos de las estaciones y lee datos de un archivo csv que
% contiene informacion sobre como se interconectan los sectores del mapa
% jerarquizado del metro.
iniciaRouter:-
    cargaDatosA,
    ArchivoC = 'C:/Users/super/Documents/Documentos Escolares/ITAM/S�ptimo Semestre/Inteligencia Artificial/IA_GIT/Proyecto3/conexiones_sector.csv',
    get_rows_data(ArchivoC,Conexiones),
    escribeConexiones(Conexiones).
%---------------------------------------------------------------------------------
%
% ---------------------------------Conexiones-------------------------------------
%Una conexion se define de la siguiente manera:
%conexion(sector1, sector2, estacion1, estacion2, sectorInt)
%La conexion puede ser de dos formas:
% 1) mostrar si sector1 y sector2 son contiguos
% (estacion1=estacion2=sectorInt = 0)
% o no (estacion1=estacion2=0 y
% sectorInt != 0)
% 2) mostrar a traves de cuales estaciones se conectan los sectores
% contiguos
% (estacion1 != 0 y estacion2 != 0 y sectorInt = 0)


%Agrega las conexiones de una lista a la base de conocimientos
/*
Los datos leidos del archivo csv se encuentran en listas con la estructura:
[sector1, sector2, estacion1, estacion2, sectorInt].

Esta funcion realiza asserts para agregar a la base de conocimientos dos
instancias de la conexion (puesto que es no dirigida), ambas con el
mismo sector intermedio, una con sector1 como origen y otra con sector2
como origen.
*/
escribeConexiones([]):-!.
escribeConexiones([[Sector1|[Sector2|[Estacion1|[Estacion2|[SectorInt|_]]]]]|ListsT]):-
    assert(conexion(Sector1, Sector2, Estacion1, Estacion2, SectorInt)),
    assert(conexion(Sector2, Sector1, Estacion2, Estacion1, SectorInt)),
    escribeConexiones(ListsT).

%---------------------------------------------------------------------------------

% -----------------------------------Casos----------------------------------------
% Un caso se define de la siguiente manera:
% caso(estOri,estDest,camino)
% y almacena un camino conocido entre dos estaciones.
% ---------------------------------------------------------------------------------

% -----------------------------------Router----------------------------------------
% split_At
split_at_(Rest, 0, [], Rest) :- !.
split_at_([], N, [], []) :-
    N > 0.
split_at_([X|Xs], N, [X|Take], Rest) :-
    N > 0,
    succ(N0, N),
    split_at_(Xs, N0, Take, Rest).

%Depura el camino
cuentaPos([],_,1):-!.
cuentaPos([CaminoH|_],CaminoH,1):-!.
cuentaPos([_|CaminoT],Target,Pos):-
    cuentaPos(CaminoT,Target,NewPos),
    Pos is NewPos + 1.
depura(Camino,Destino,Res):-
    cuentaPos(Camino,Destino,Pos),
    split_at(Pos,Camino,Res,_).


% Obtiene en Res el sector intermedio por el que se debe pasar para
% llegar de SecOri a SecDest
getSectorInt(SecOri, SecDest, Res):-
    findall(Val, conexion(SecOri, SecDest, 0, 0, Val), [Res|_]).

% Elige en Cam de entre las rutas designadas que conectan sectores
% aquella que acerca mas al destino final
eligeCamDes(SecOri, EstDest, SecDest, Cam):-
    findall(Dest, conexion(SecOri, SecDest,Dest,_, _), Res),
    menorCamDes(Res,Cam,EstDest).

% De una lista de estaciones devuelve en Cam el elemento que tenga
% menor distancia haversine a un destino dado
menorCamDes([CamH|CamT],Cam,Dest):-
  menorCamDes([CamH|CamT],inf,CamH,Cam,Dest).
menorCamDes([],_,X,X,_):-!.
menorCamDes([CamH|CamT],Menor,Actual,Cam,Dest):-
  distHaversine(CamH,Dest,Val),
  Val < Menor -> menorCamDes(CamT,Val,CamH,Cam,Dest);
  menorCamDes(CamT,Menor,Actual,Cam,Dest).

% Dadas una estacion origen y una estacion final, busca si en la base de
% conocimientos existe algun camino que conecte a ambas estaciones en
% cualquier direccion. Si existe, lo devuelve en X (de ser necesario
% antes invierte el camino). De lo contrario, lo calcula en X mediante
% creaCaso y lo agrega a la base de conocimientos.
buscaCaso(EstOri, EstDest, X):-
    EstOri == EstDest -> X = [EstOri], !;
    findall(Camino, caso(EstOri,EstDest,Camino),[X|_]) -> !;
    findall(Camino, caso(EstDest,EstOri,Camino),[Aux|_]) -> invierte(Aux,X),!;
    findall(Camino, caso(EstOri,_,Camino),CasoOri),
    CasoOri == [] -> creaCaso(EstOri, EstDest, Y), depura(Y,EstDest,X), assert(caso(EstOri,EstDest,X));
    findall(EstSig, caso(EstOri,EstSig,_), Destinos),
    menorCamDes(Destinos,Siguiente,EstDest),
    buscaCaso(Siguiente,EstDest,Aux),
    findall(Camino, caso(EstOri,Siguiente,Camino), [Creo|_]),
    eliminaUltimo(Creo,Creemos),
    append(Creemos,Aux,Y),
    depura(Y,EstDest,X),
    assert(caso(EstOri,EstDest,X)).

creaCaso(EstOri, EstDest, X):-
    getSector(EstOri,S1),
    getSector(EstDest,S2),
    S1 == S2 -> aEstrellaGeo(EstOri,EstDest,X);
    getSector(EstOri,S1),
    getSector(EstDest,S2),
    getSectorInt(S1,S2,SInt),
    SInt == 0 -> (eligeCamDes(S1,EstDest,S2,Con1),
                  findall(Siguiente, conexion(S1,S2,Con1,Siguiente,_),[Con1Next|_]),
                  buscaCaso(EstOri,Con1,C1),
                  buscaCaso(Con1Next,EstDest,C2),
                  append(C1,C2,X));
    getSector(EstOri,S1),
    getSector(EstDest,S2),
    getSectorInt(S1,S2,SInt),
    SInt \== 0 -> (eligeCamDes(S1,EstDest,SInt,ConInt1),
                   buscaCaso(EstOri,ConInt1,CInt1),
                   findall(Siguiente1, conexion(S1,SInt,ConInt1,Siguiente1,_),[ConI1Next|_]),
                   eligeCamDes(SInt,EstDest,S2,ConInt2),
                   buscaCaso(ConI1Next,ConInt2,CInt2),
                   findall(Siguiente2, conexion(SInt,S2,ConInt2,Siguiente2,_),[ConI2Next|_]),
                   buscaCaso(ConI2Next,EstDest,CInt3),
                   append(CInt1,CInt2,Aux),
                   append(Aux,CInt3,X)).

%Funcion que llama el usuario
% Dadas una estacion origen y una destino, imprime el camino mas corto
% que las conecta.
router(EstOri,EstDest):-
   buscaCaso(EstOri,EstDest,X),
   imprimeCamino(X).
%---------------------------------------------------------------------------------











