/*
   Copyright 2016  Georgia Institute of Technology

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License. 
*/
 create or replace procedure omop.generic_create_conditions(v_loadid int)
 as
        rowcnt  integer;

    begin

        etl.logm('generic_create_conditions', 'generic_create_conditions' , 'START' );

        insert into omop.condition_occurrence_temp
        (
              condition_occurrence_id,
              person_id,
              condition_concept_id,
              condition_start_date,
              condition_end_date,
              condition_type_concept_id,
              stop_reason,
              provider_id,
              visit_occurrence_id,
              condition_source_value,
              condition_source_concept_id,
              x_srcid,
              x_srcloadid,
              x_srcfile
        )
        select
            omop.condition_occurrence_id_seq.nextval as condition_occurrence_id
            , person_id
            , condition_concept_id
            , condition_start_date
            , condition_end_date
            , condition_type_concept_id
            , stop_reason
            , provider_id
            , visit_occurrence_id
            , condition_source_value
            , condition_source_concept_id
            , x_srcid
            , x_srcloadid
            , x_srcfile
        from
        (
            select distinct
                p.person_id as person_id
                , coalesce(tar.concept_id, 0 ) as condition_concept_id
                , s.start_date as condition_start_date
                , s.end_date as condition_end_date
                , s.condition_source_type_value as condition_type_concept_id
                , null as stop_reason
                , coalesce( pr.provider_id, v.provider_id, 0 ) as provider_id
                , coalesce( v.visit_occurrence_id, 0 ) as visit_occurrence_id
                , s.condition_source_value as condition_source_value
                , coalesce(src.concept_id, 0) as condition_source_concept_id
                , s.id as x_srcid
		, s.load_id as x_srcloadid
                , 'STAGE_CONDITION' as x_srcfile
            from etl.stage_condition_temp s
            join omop.person p on p.person_source_value = s.person_source_value
            left join omop.visit_occurrence v on s.visit_source_value = v.visit_source_value
            left join omop.concept src on s.condition_source_value = replace(src.concept_code, '.', '' )
              			and src.domain_id like '%Condition%'
              			and coalesce(s.condition_code_source_type, src.vocabulary_id ) = src.vocabulary_id
              			and src.invalid_reason is null
            left join omop.concept_relationship cr on src.concept_id = cr.concept_id_1
              			and cr.relationship_id = 'Maps to'
              			and cr.invalid_reason is null
            left join omop.concept tar on cr.concept_id_2 = tar.concept_id
              			and tar.standard_concept = 'S'
              			and tar.invalid_reason is null
            left join omop.provider pr on s.provider_source_value = pr.provider_source_value
		where s.start_date is not null
		and s.load_id = coalesce(v_loadid, s.load_id )
        ) a
        ;

        rowcnt := SQL%ROWCOUNT;

        etl.logm('generic_create_conditions', 'insert into condition_occurrence' , rowcnt );

        etl.logm('generic_create_conditions', 'generic_create_conditions' , 'FINISH' );

        etl.logm('generic_create_conditions', 'generic_create_cond_measurements from conditions' , 'START' );

        insert into omop.measurement_temp
        (
            measurement_id,
            person_id,
            measurement_concept_id,
            measurement_date,
            measurement_type_concept_id,
            value_as_concept_id,
            visit_occurrence_id,
            measurement_source_value,
            measurement_source_concept_id,
            provider_id,
            x_srcid,
            x_srcloadid,
            x_srcfile
        )
        select
            omop.measurement_id_seq.nextval as measurement_id
            , person_id
            , measurement_concept_id
            , measurement_date
            , measurement_type_concept_id
            , value_as_concept_id
            , visit_occurrence_id
            , measurement_source_value
            , measurement_source_concept_id
            , provider_id
            , x_srcid
            , x_srcloadid
            , x_srcfile
        from
        (
            select distinct
                p.person_id as person_id
                , coalesce(tar.concept_id, 0 )  as measurement_concept_id
                , s.start_date as measurement_date
                , 44818701 as measurement_type_concept_id  -- 'From physical examination' -- TODO: may need to be changed
                , val.concept_id as value_as_concept_id
                , v.visit_occurrence_id as visit_occurrence_id
                , s.condition_source_value as measurement_source_value
                , coalesce(tar.concept_id, 0) as measurement_source_concept_id
                , pr.provider_id
                , s.id as x_srcid
		, s.load_id as x_srcloadid
                , 'STAGE_CONDITION' as x_srcfile
            from etl.stage_condition_temp s
            join omop.person p on p.person_source_value = s.person_source_value
            left join omop.visit_occurrence v on s.visit_source_value = v.visit_source_value
            join omop.concept src on s.condition_source_value = replace(src.concept_code, '.', '' )
                            and src.domain_id like '%Meas%'
                            and coalesce(s.condition_code_source_type, src.vocabulary_id ) = src.vocabulary_id
                            and src.invalid_reason is null
            left join omop.concept_relationship cr on src.concept_id = cr.concept_id_1
                      			and cr.relationship_id = 'Maps to'
                      			and cr.invalid_reason is null
            left join omop.concept tar on cr.concept_id_2 = tar.concept_id
                      			and tar.standard_concept = 'S'
                      			and tar.invalid_reason is null
            left join omop.concept_relationship crv on src.concept_id = crv.concept_id_1
                      			and crv.relationship_id = 'Maps to value'
                      			and crv.invalid_reason is null
            left join omop.concept val on crv.concept_id_2 = val.concept_id
                      			and val.standard_concept = 'S'
                      			and val.invalid_reason is null
            left join omop.provider pr on s.provider_source_value = pr.provider_source_value
		where s.start_date is not null
		and s.load_id = coalesce(v_loadid, s.load_id )
        ) a
        ;

        rowcnt := SQL%ROWCOUNT;

        etl.logm('generic_create_conditions', 'insert into measurements' , rowcnt );

        etl.logm('generic_create_conditions', 'generic_create_cond_measurements from conditions' , 'FINISH' );



        etl.logm('generic_create_conditions', 'generic_create_cond_observations from conditions' , 'START' );

        insert into omop.observation_temp
        (
            observation_id,
            person_id,
            observation_concept_id,
            observation_date,
            observation_type_concept_id,
            value_as_concept_id,
            visit_occurrence_id,
            observation_source_value,
            observation_source_concept_id,
            provider_id,
            x_srcid,
            x_srcloadid,
            x_srcfile
        )
        select
            omop.observation_id_seq.nextval as observation_id
            , person_id
            , observation_concept_id
            , observation_date
            , observation_type_concept_id
            , value_as_concept_id
            , visit_occurrence_id
            , observation_source_value
            , observation_source_concept_id
            , provider_id
            , x_srcid
            , x_srcloadid
            , x_srcfile
        from
        (
            select 
                p.person_id as person_id
                , coalesce(tar.concept_id, 0 )  as observation_concept_id
                , s.start_date as observation_date
                , 38000280 as observation_type_concept_id  -- 'Observation recorded from EHR'  -- TODO: may need to be changed
                , val.concept_id as value_as_concept_id
                , v.visit_occurrence_id as visit_occurrence_id
                , s.condition_source_value as observation_source_value
                , coalesce(src.concept_id, 0) as observation_source_concept_id
                , pr.provider_id
                , s.id as x_srcid
		, s.load_id as x_srcloadid
                , 'STAGE_CONDITION' as x_srcfile
            from etl.stage_condition_temp s
            join omop.person p on p.person_source_value = s.person_source_value
            left join omop.visit_occurrence v on s.visit_source_value = v.visit_source_value
            join omop.concept src on s.condition_source_value = replace(src.concept_code, '.', '' )
                    and src.domain_id like '%Obs%'
                    and coalesce(s.condition_code_source_type, src.vocabulary_id ) = src.vocabulary_id
                    and src.invalid_reason is null
            left join omop.concept_relationship cr on src.concept_id = cr.concept_id_1
              			and cr.relationship_id = 'Maps to'
              			and cr.invalid_reason is null
            left join omop.concept tar on cr.concept_id_2 = tar.concept_id
              			and tar.standard_concept = 'S'
              			and tar.invalid_reason is null
            left join omop.concept_relationship crv on src.concept_id = crv.concept_id_1
              			and crv.relationship_id = 'Maps to value'
              			and crv.invalid_reason is null
            left join omop.concept val on crv.concept_id_2 = val.concept_id
              			and val.standard_concept = 'S'
              			and val.invalid_reason is null
            left join omop.provider pr on s.provider_source_value = pr.provider_source_value
		where s.start_date is not null
		and s.load_id = coalesce(v_loadid, s.load_id )
        ) a
        ;

        rowcnt := SQL%ROWCOUNT;

        etl.logm('generic_create_conditions', 'insert into observation' , rowcnt );

        etl.logm('generic_create_conditions', 'generic_create_cond_observations from conditions' , 'FINISH' );



-- Condition/Drug not needed as there are no mapped concepts to that domain
-- create or replace function omop.generic_create_cond_drug_exposure()


        etl.logm('generic_create_conditions', 'generic_create_cond_procedures from conditions' , 'START' );

	INSERT INTO omop.procedure_occurrence_temp
	(
		procedure_occurrence_id,
		person_id,
		procedure_concept_id,
		procedure_date,
		procedure_type_concept_id,
		provider_id,
		visit_occurrence_id,
		procedure_source_value,
		procedure_source_concept_id,
                x_srcid,
                x_srcloadid,
                x_srcfile
	)
	select
		omop.procedure_occurrence_id_seq.nextval as procedure_occurrence_id,
		person_id,
		procedure_concept_id,
		procedure_date,
		procedure_type_concept_id,
		provider_id,
		visit_occurrence_id,
		procedure_source_value,
		procedure_source_concept_id,
                x_srcid,
                x_srcloadid,
                x_srcfile
	from
        (
          select
            p.person_id as person_id
            , coalesce(tar.concept_id, 0 ) as procedure_concept_id
            , s.start_date as procedure_date
            , s.condition_source_type_value as procedure_type_concept_id
            , coalesce( pr.provider_id, v.provider_id, 0 ) as provider_id
            , coalesce( v.visit_occurrence_id, 0 ) as visit_occurrence_id
            , s.condition_source_value as procedure_source_value
            , coalesce(src.concept_id, 0) as procedure_source_concept_id
            , s.id as x_srcid
            , s.load_id as x_srcloadid
            , 'STAGE_CONDITION' as x_srcfile
        from etl.stage_condition_temp s
        join omop.person p on p.person_source_value = s.person_source_value
        left join omop.visit_occurrence v on s.visit_source_value = v.visit_source_value
        join omop.concept src on s.condition_source_value = replace(src.concept_code, '.', '' )
                        and src.domain_id like '%Proc%'  -- full join only want proc matches.
                        and coalesce(s.condition_code_source_type, src.vocabulary_id ) = src.vocabulary_id
			                  and src.invalid_reason is null
        left join omop.concept_relationship cr on src.concept_id = cr.concept_id_1
                        and cr.relationship_id = 'Maps to'
			                  and cr.invalid_reason is null
        left join omop.concept tar on cr.concept_id_2 = tar.concept_id
                        and tar.standard_concept = 'S'
                  			and tar.invalid_reason is null
        left join omop.provider pr on s.provider_source_value = pr.provider_source_value
		where s.start_date is not null
		and s.load_id = coalesce(v_loadid, s.load_id )
       ) a;

        rowcnt := SQL%ROWCOUNT;

        etl.logm('generic_create_conditions', 'insert into procedure_occurrence' , rowcnt );

        etl.logm('generic_create_conditions', 'generic_create_cond_procedures from conditions' , 'FINISH' );

    end;

