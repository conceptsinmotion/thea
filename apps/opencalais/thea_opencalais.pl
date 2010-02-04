/*

Hello

*/


:- module(thea_opencalais,
	  [ oc_rest/3,
	    oc_entity/5,
	    oc_relation/3,
	    oc_resolution/3
	  ]).

:-use_module(library('http/http_client')).
:-use_module(library('sgml')).
:-use_module(library('sgml_write')).
:-use_module('../../owl2_model.pl').
:-use_module('../../owl2_from_rdf.pl').
:-use_module('../../owl2_rl_rules.pl').
:-use_module('../../owl2_util.pl').


/** <module> Thea wrapper for open calais service.

Open Calais service wrapper

  @author Vangelis Vassiliadis
  @license GPL


*/


:- dynamic open_calais/1.

open_calais(class('http://s.opencalais.com/1/type/er/Geo/Country')).
open_calais(class('http://s.opencalais.com/1/type/er/Geo/City')).
open_calais(license('nbqjkw3dn3mfhmuejy7h9c62')).

%% oc_rest(+Request, +Params:string, -Result) is det
%
% Calls Open Calais Rest service and posts the Request.
% Requires a valid Open_Calais license key in a dynamic
% open_calais(license(License)) to be asserted.
%
% @param Request can be any of the following:
%   * http(URL)
%   * file(Filename)
%   * text(Atom)
% @param Params is a string encoded XML see description in
% http://www.opencalais.com/APICalls
%
% @param Result is the RDF response of Open_Calais see
% http://www.opencalais.com/documentation/calais-web-service-api/interpreting-api-response/rdf
%
%


oc_rest(_Request,_Params,_Result) :-
	not(open_calais(license(_))),
	throw(open_calais_exception(missing_license)),!.

oc_rest(Request,Params,Result) :-
	open_calais(license(LicenseID)),
        (   Request = http(URL) -> http_get(URL,Content,[]);
	Request = file(Filename) -> read_file_to_codes(Filename,Codes,[]),atom_codes(Content,Codes) ;
	Request = text(Content) -> true ; throw(open_calais_exception(invalid_request_type))),

	http_post('api.opencalais.com/enlighten/rest/',
		  form(['licenseID'=LicenseID,content=Content,paramsXML=Params]),
		  Result,[]),
	open('_opencalais',write,St),
	write(St,'<?xml version="1.0"?>'),nl(St),write(St,Result),
	close(St),
	owl_parse_rdf('_opencalais',[imports(false)]).



%% oc_entity(?I, ?C, -PV:list, +Instance:list, +Resolutions:list) is nondet
%
% Returns the markup element entities in the response to an Open Calais
% request
%
% @param I is the returned markup entity ID (IRI)
% @param C is the entitie's markup type
% @param PV list of property value pairs for the entity
% @param Instance List of instance_info terms for the specific entity
% @param Resolutions List of resolution terms for the specific
% entity


oc_entity(I,C,PVList,Instances,Resolutions) :-
	is_entailed(subClassOf(C,'http://s.opencalais.com/1/type/em/e/MarkupEntity'),_),
	classAssertion(C,I),
	findall(P=V,propertyAssertion(P,I,V),PVList),

	findall(instance_info(Instance,InstancePV),
		( propertyAssertion('http://s.opencalais.com/1/pred/subject',Instance,I),
		  classAssertion('http://s.opencalais.com/1/type/sys/InstanceInfo',Instance),
		  findall(P=V,propertyAssertion(P,Instance,V),InstancePV)
		),
		Instances),
	findall(resolution_info(Resolution,ResolutionPV),
		( propertyAssertion('http://s.opencalais.com/1/pred/subject',Resolution,I),
		  is_entailed(subClassOf(RC,'http://s.opencalais.com/1/type/er/ResolvedEntity'),_),
		  classAssertion(RC,Resolution),
		  findall(P=V,propertyAssertion(P,Resolution,V),ResolutionPV)
		),
		Resolutions).

%% oc_relation(?I, ?C, -PV:list) is nondet
%
% Returns the markup element relations in the response to an Open Calais
% request
%
% @param I is the returned markup relation ID (IRI)
% @param C is the relation's markup type
% @param PV list of property value pairs for the relation

oc_relation(I,C,PVList) :-
	class(C),subClassOf(C,'http://s.opencalais.com/1/type/em/r/Relation'),
	classAssertion(C,I),
	findall(P=V,propertyAssertion(P,I,V),PVList).


%% oc_resolution(?R, ?C, -PV:list) is nondet
%
% Returns the resolutions in the response to an  Open Calais request
%
% @param R is the returned resolution ID (IRI)
% @param C is the resolution's type
% @param PV list of property value pairs for the resolution

oc_resolution(R,C,PVList) :-
	is_entailed(subClassOf(C,'http://s.opencalais.com/1/type/er/ResolvedEntity'),_Expl),
	classAssertion(C,R),
	findall(P=V,propertyAssertion(P,R,V),PVList).


% ---
% Usage
%


o :- owl_parse_rdf('owl.opencalais-4.3.xml.owl',[imports(false),clear(complete)]).
pope :- oc_rest(http('http://news.bbc.co.uk/2/hi/uk_news/8492597.stm'),'',_X).
un :- oc_rest(http('http://www.scoop.co.nz/stories/WO0002/S00002.htm'),'',_X).
%  papal_visits :- oc_rest(http('http://en.wikipedia.org/wiki/List_of_journeys_of_Pope_Benedict_XVI'),'',_X).
papal_visits :- oc_rest(file(papal_visits),'',_X).
stats(File) :- owl_statistics(all,XML), open(File,write,S), xml_write(S,XML,[header(true)]),close(S).

dereference(URI,Options):-
	catch(owl_parse_rdf(URI,Options),io_error(A,B,C),(nl,nl,print(A-B-C),nl,nl)).

dereference(URI,Options,Ext) :-
	atom_concat(URI,Ext,Ext_URI),
	catch(owl_parse_rdf(Ext_URI,Options),io_error(A,B,C),(nl,nl,print(A-B-C),nl,nl)).
