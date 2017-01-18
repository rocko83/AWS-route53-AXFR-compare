#!/bin/bash
#Alexandre D'Amato
export BASENAME=base.db
export BINARIO=$0
function ajuda() {
	echo -e "############################################################################\n"
	echo SCRIPT PARA CONFLITAR REGISTROS DNS E GERAR SAIDA DE MODIFICACAO PARA CLI53 
	echo Este script ira popular uma base sqlite e com registros do route53 AWS e comflitar com os registros do UltraDNS.
	echo Nao sera validado registros diferentes do tipo A e CNAME
	echo Argumentos validos sao:
	echo -e "\t$0 [COMANDO] <ARGUMENTOs>"
	echo -e "\t$0 ajuda"
	echo -e "\t$0 listar [-f]"
	echo -e "\t$0 cadastrar <alias> <TTL> <tipo> <Target>"
	echo -e "\t$0 conflitar <alias> <TTL> <tipo> <Target>"
	echo -e "\t$0 processar [ -f2 |<AXFR do AWS>] <AXFR do UltraDNS>"
	echo -e "\t$0 apagatudo"
	echo -e "\n"
}
function iniciar() {
	sqlexec "create table IF NOT EXISTS dns(nome varchar(60) ,TTL integer, tipo varchar(30),endereco varchar(65))"
}
function sqlexec() {
	echo -e "\e[42m" > /dev/stderr
	#date > /dev/stderr
	echo -e "\e[44m" > /dev/stderr
	echo sqlite3 $BASENAME "$1" > /dev/stderr
	echo -en "\e[0m" > /dev/stderr
	sqlite3 $BASENAME "$1"
}
function cadastrar() {
	sqlexec "insert into dns values ('$1','$2','$3','$4')"
}
function listar() {
	sqlexec "select * from dns"
}
function apagatudo() {
	sqlexec "delete from dns"
}
function processar(){
	$0 apagatudo
	if [ ! -f $1 ] 
	then
		echo Arquivo \"$1\" nao existe\/ nao foi encontrado\/ ou nao ha permissao para acesso
		exit 1
	fi
	if [ ! -f $2 ] 
	then
		echo Arquivo \"$2\" nao existe\/ nao foi encontrado\/ ou nao ha permissao para acesso
		exit 1
	fi
	cat $1 | egrep -w "A|CNAME" |sed -e "s/	/ /g" -e "s///g" -e "s/IN//g" | xargs -i .$BINARIO cadastrar {}
	cat $2 | egrep -w "A|CNAME" |sed -e "s/	/ /g" -e "s///g" -e "s/IN//g" | xargs -i .$BINARIO conflitar {} 
}
function processar2(){
	if [ ! -f $1 ] 
	then
		echo Arquivo \"$1\" nao existe\/ nao foi encontrado\/ ou nao ha permissao para acesso
		exit 1
	fi
	cat $1 | egrep -w "A|CNAME" |sed -e "s/	/ /g" -e "s///g" -e "s/IN//g" | xargs -i .$BINARIO conflitar {} 
}
function faltaargumento() {
	clear
	echo -e "\e[41m" 
	date
	echo Falta de argumento
	echo -e "\e[0m" 
	ajuda
	exit 1
}
function conflitar() {
	retorno=$(sqlexec "select nome from dns where nome like '$1'"| wc -l)
	if [ $retorno -eq 0 ]
	then
		echo Registro nao encontrado > /dev/stderr
		echo RC=$retorno > /dev/stderr
		echo   \"$1 $2 $3 $4\"
	else
		retorno=$(sqlexec "select nome from dns where nome like '$1' and tipo like '$3'"| wc -l)
		if [ $retorno -eq 0 ]
		then
			echo Registro nao encontrado > /dev/stderr
			echo RC=$retorno > /dev/stderr
			echo  ./cli53 rrcreate --replace ZONA \"$1 $2 $3 $4\"
		else
			retorno=$(sqlexec "select nome from dns where nome like '$1' and tipo like '$3' and endereco like '$4'"| wc -l)
			if [ $retorno -eq 0 ]
			then
				echo Registro nao encontrado > /dev/stderr
				echo RC=$retorno > /dev/stderr
				echo  ./cli53 rrcreate  --replace ZONA \"$1 $2 $3 $4\"
			else
				retorno=$(sqlexec "select nome from dns where nome like '$1' and tipo like '$3' and endereco like '$4' and TTL == '$2'"| wc -l)
				if [ $retorno -eq 0 ]
				then
					echo Registro nao encontrado > /dev/stderr
					echo RC=$retorno > /dev/stderr
					echo ./cli53 rrcreate --replace ZONA \"$1 $2 $3 $4\"
				fi
			fi
		fi
	fi
}
iniciar  2>/dev/null
case $1 in
	cadastrar)
		if [ $# -ne 5 ]
		then
			faltaargumento
		else
			cadastrar $2 $3 $4 $5
		fi
		;;
	listar)
		if [ "$2" == "-f" ]
		then
			listar | column -s \| -t
		else
			listar 
		fi
		;;
	apagatudo)
		apagatudo
		;;
	conflitar)
		if [ $# -ne 5 ]
		then
			faltaargumento
		else
			conflitar $2 $3 $4 $5
		fi
		;;
	processar)
		if [ $# -ne 3 ]
		then
			faltaargumento
		else
			if [ "$2" == "-f2" ]
			then
				processar2 $3
			else
				processar $2 $3
			fi
		fi
		;;
	*)
		ajuda
		;;
esac
