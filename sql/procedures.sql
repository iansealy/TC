/** procedures **/

/** update the ena accession number in the sequence_plate table with an ID from the warehouse db **/
DELIMITER $$
DROP PROCEDURE IF EXISTS updateENAid$$
 
CREATE PROCEDURE updateENAid (
 IN sample_name_param varchar(255),
 IN ena_id_param varchar(255),
 IN exp_id_param INT(10)
)
BEGIN

 UPDATE sequence_plate seqp INNER JOIN rna_dilution_plate rdp 
 ON rdp.id = seqp.rna_dilution_plate_id 
 SET seqp.ena_accession = ena_id_param 
 WHERE seqp.sample_public_name = sample_name_param 
 AND rdp.experiment_id = exp_id_param;
END$$
DELIMITER ;

/** update a study name for an experiment **/
DELIMITER $$
DROP PROCEDURE IF EXISTS updateExpStdName$$

CREATE PROCEDURE updateExpStdName (
 IN study_name_param varchar(255),
 IN exp_id_param INT(10)
)
BEGIN

 UPDATE experiment exp SET exp.study_id = 
  (
   SELECT id 
   FROM study std
   WHERE std.name = study_name_param 
  ) 
 WHERE exp.id = exp_id_param;
END$$
DELIMITER ;

/** delete entries from rna_extraction table - if experiment data was not successfully entered **/
DELIMITER $$
DROP PROCEDURE IF EXISTS del_rna_data$$

CREATE PROCEDURE del_rna_data (
 IN rna_exp_id_param INT(10)
)
BEGIN

DELETE rnaext.*
FROM rna_extraction rnaext
WHERE id = rna_exp_id_param;
END$$
DELIMITER ;

/** delete a study **/
DELIMITER $$
DROP PROCEDURE IF EXISTS delStd$$

CREATE PROCEDURE delStd (
 IN std_id_param INT(10)
)
BEGIN

DELETE std.* 
FROM study std
WHERE id = std_id_param;
END$$
DELIMITER ;

/** delete entry from zmp_allele_phenotype_eq table **/
DELIMITER $$
DROP PROCEDURE IF EXISTS delete_zap$$

CREATE PROCEDURE delete_zap (
 IN zap_id_param INT(10)
)
BEGIN

DELETE zap.* 
FROM zmp_allele_phenotype_eq zap
WHERE zap.id = zap_id_param;
END$$
DELIMITER ;

/** update phenotype in sequence_plate table **/
DELIMITER $$
DROP PROCEDURE IF EXISTS update_pheno$$

CREATE PROCEDURE update_pheno (
 IN seqp_id_param INT(10),
 IN pheno_param ENUM('Phenotypic','Non-Phenotypic','Unknown') 
)
BEGIN

UPDATE sequence_plate 
SET phenotype = pheno_param
WHERE id = seqp_id_param;
END$$
DELIMITER ;

/** delete experiment and rna_extraction record **/
DELIMITER $$
DROP PROCEDURE IF EXISTS delete_exp$$

CREATE PROCEDURE delete_exp (
 IN exp_id_param INT(10)
)
BEGIN

SET foreign_key_checks = 0;
DELETE seqp.*,
       gt.*,
       rdp.*,
       rna_ext.*,
       exp.* 
FROM experiment exp INNER JOIN rna_extraction rna_ext
       ON exp.rna_extraction_id = rna_ext.id LEFT OUTER JOIN rna_dilution_plate rdp
       ON rdp.experiment_id = exp.id LEFT OUTER JOIN genotype gt 
       ON gt.rna_dilution_plate_id = rdp.id LEFT OUTER JOIN sequence_plate seqp
       ON seqp.rna_dilution_plate_id = rdp.id
WHERE exp.id = exp_id_param;
SET foreign_key_checks = 1;
END$$
DELIMITER ;

/** delete experiments which have no rna_dilution_plate entries **/
DELIMITER $$
DROP PROCEDURE IF EXISTS delAllExp$$

CREATE PROCEDURE delAllExp (
)
BEGIN

DELETE genot.*,
       seqp.*,
       rdp.*,
       rna_ext.*,
       exp.*
FROM experiment exp LEFT OUTER JOIN rna_extraction rna_ext
       ON rna_ext.id = exp.rna_extraction_id LEFT OUTER JOIN rna_dilution_plate rdp 
       ON rdp.experiment_id = exp.id LEFT OUTER JOIN sequence_plate seqp
       ON seqp.rna_dilution_plate_id = rdp.id LEFT OUTER JOIN genotype genot 
       ON genot.rna_dilution_plate_id = rdp.id INNER JOIN expsToDelete etd 
       ON exp.id = etd.exp_id;
END$$
DELIMITER ;

/** genotype **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_genotype_data$$

CREATE PROCEDURE add_genotype_data (
 IN allele_id_param INT(10),
 IN rna_dilution_plate_id_param INT(10),
 IN name_param ENUM('Het','Hom','Wildtype','Failed','Missing','Blank'),
 IN sample_comment_param MEDIUMTEXT
)
BEGIN

INSERT IGNORE INTO genotype (
 allele_id,
 rna_dilution_plate_id,
 name,
 sample_comment
)
VALUES (
 allele_id_param,
 rna_dilution_plate_id_param,
 name_param,
 sample_comment_param
);
END$$
DELIMITER ;

/** insert a new allele **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_a_new_allele$$

CREATE PROCEDURE add_a_new_allele (
 IN allele_name_param VARCHAR(255),
 IN gene_name_param VARCHAR(255),
 IN snp_id_param VARCHAR(255),
 OUT insert_id int(10)
)
BEGIN

INSERT INTO allele (
 name,
 gene_name,
 snp_id
)
VALUES (
 allele_name_param,
 IFNULL(gene_name_param, DEFAULT(gene_name)),
 IFNULL(snp_id_param, DEFAULT(snp_id))
);
SET insert_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** update a treatment with a compound and dose **/
DELIMITER $$
DROP PROCEDURE IF EXISTS addCompound$$

CREATE PROCEDURE addCompound (
 IN seqp_id_param INT(10),
 IN compound_param  MEDIUMTEXT,
 IN dose_param MEDIUMTEXT
)
BEGIN

UPDATE treatment 
SET compound = compound_param,
    dose = dose_param
WHERE sequence_plate_id = seqp_id_param
AND treatment_type = 'Small molecule screen';
END$$
DELIMITER $$ 

/** insert a treatment **/
DELIMITER $$
DROP PROCEDURE IF EXISTS addTreatment$$

CREATE PROCEDURE addTreatment (
 IN seqp_id_param INT(10),
 IN treatment_type_param ENUM('Small molecule screen','Infection challenge','Gene knockout','No treatment'),
 IN treatment_description_param MEDIUMTEXT 
)
BEGIN

REPLACE INTO treatment (
 sequence_plate_id,
 treatment_type,
 treatment_description
)
VALUES (
 seqp_id_param,
 IFNULL(treatment_type_param, DEFAULT(treatment_type)),
 IFNULL(treatment_description_param, DEFAULT(treatment_description))
);
END$$
DELIMITER ;

/** zmp_allele_phenotype_eq **/
DELIMITER $$
DROP PROCEDURE IF EXISTS insert_zmp_allele_phenotype_eq$$

CREATE PROCEDURE insert_zmp_allele_phenotype_eq (
 IN genome_reference_id_param INT(10),
 IN snp_id_param VARCHAR(255),
 IN allele_id_param INT(10),
 IN stage_param VARCHAR(255),
 IN entity1_param VARCHAR(255),
 IN entity2_param VARCHAR(255),
 IN quality_param VARCHAR(255),
 IN tag_param VARCHAR(255),
 OUT insert_id int(10)
)
BEGIN

INSERT INTO zmp_allele_phenotype_eq (
 genome_reference_id,
 snp_id,
 allele_id,
 stage,
 entity1,
 entity2,
 quality,
 tag
) 
VALUES (
 genome_reference_id_param,
 snp_id_param,
 allele_id_param,
 stage_param,
 entity1_param,
 entity2_param,
 quality_param,
 tag_param
);
SET insert_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** sequence_plate **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_sequence_plate_data$$

CREATE PROCEDURE add_sequence_plate_data (
 IN plate_name_param VARCHAR(255),
 IN well_name_param VARCHAR(255),
 IN sample_name_param VARCHAR(255),
 IN sample_public_name_param VARCHAR(255),
 IN rna_dilution_plate_id_param INT(10),
 IN index_tag_id_param INT(10),
 IN color_param VARCHAR(255),
 IN sample_volume_param FLOAT,
 IN water_volume_param FLOAT,
 IN sample_amount_param FLOAT
)
BEGIN

INSERT IGNORE INTO sequence_plate (
 plate_name,
 well_name,
 sample_name,
 sample_public_name,
 rna_dilution_plate_id,
 index_tag_id,
 color,
 sample_volume,
 water_volume,
 sample_amount
)
VALUES (
 plate_name_param,
 well_name_param,
 sample_name_param,
 sample_public_name_param,
 rna_dilution_plate_id_param,
 index_tag_id_param,
 color_param,
 sample_volume_param,
 water_volume_param,
 sample_amount_param
);
END$$
DELIMITER ;


/** rna_dilution_plate **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_rna_dilution_data$$

CREATE PROCEDURE add_rna_dilution_data (
 IN experiment_id_param INT(10),
 IN rna_amount_param FLOAT,
 IN rna_volume_param FLOAT,
 IN well_name_param VARCHAR(255),
 IN cut_off_amount_param FLOAT,
 IN qc_pass_param TINYINT(1),
 IN selected_for_sequencing_param TINYINT(1),
 IN final_sample_volume_param FLOAT,
 OUT rna_dilution_plate_id int(10)
)
BEGIN

INSERT INTO rna_dilution_plate (
 experiment_id,
 rna_amount,
 rna_volume,
 well_name,
 cut_off_amount,
 qc_pass,
 selected_for_sequencing,
 final_sample_volume
)
VALUES (
 experiment_id_param,
 rna_amount_param,
 rna_volume_param,
 well_name_param,
 cut_off_amount_param,
 qc_pass_param,
 selected_for_sequencing_param,
 final_sample_volume_param
);
SET rna_dilution_plate_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** new study **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_new_study$$

CREATE PROCEDURE add_new_study (
 IN name_param VARCHAR(255),
 OUT study_id INT(10)
)
BEGIN

INSERT INTO study (
 name
)
VALUES (
 name_param
);
SET study_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** new assembly **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_new_assembly$$

CREATE PROCEDURE add_new_assembly (
 IN name_param VARCHAR(255),
 IN species_id_param INT(10),
 IN gc_content_param VARCHAR(255),
 OUT assembly_id INT(10)
)
BEGIN

INSERT INTO genome_reference (
 name,
 species_id,
 gc_content
)
VALUES (
 name_param,
 species_id_param,
 gc_content_param
);
SET assembly_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** new developmental_stage **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_new_devstage$$

CREATE PROCEDURE add_new_devstage (
 IN period_param VARCHAR(255),
 IN stage_param VARCHAR(255),
 IN begins_param VARCHAR(255),
 IN landmarks_param VARCHAR(255),
 IN zfs_id_param VARCHAR(255),
 OUT dev_id INT(10)
)
BEGIN

INSERT INTO developmental_stage (
 period,
 stage,
 begins,
 developmental_landmarks,
 zfs_id
)
VALUES (
 period_param,
 stage_param,
 begins_param,
 landmarks_param,
 zfs_id_param
);
SET dev_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** rna-extraction **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_rna_extraction_data$$

CREATE PROCEDURE add_rna_extraction_data (
 IN extracted_by_param VARCHAR(255),
 IN extraction_protocol_version_param VARCHAR(255),
 IN extraction_date_param DATE,
 IN library_creation_date_param DATE,
 IN library_creation_protocol_version_param VARCHAR(255),
 IN library_tube_id_param VARCHAR(255),
 OUT rna_ext_id INT(10)
)
BEGIN

INSERT INTO rna_extraction (
 extracted_by,
 extraction_protocol_version,
 extraction_date,
 library_creation_date,
 library_creation_protocol_version,
 library_tube_id
)
VALUES (
 extracted_by_param,
 extraction_protocol_version_param,
 extraction_date_param,
 library_creation_date_param,
 library_creation_protocol_version_param,
 library_tube_id_param
);
SET rna_ext_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** experiment **/
DELIMITER $$
DROP PROCEDURE IF EXISTS add_experiment_data$$
 
CREATE PROCEDURE add_experiment_data (
 IN rna_extraction_id_param INT(10),
 IN image_param VARCHAR(255),
 IN study_id_param INT(10),
 IN genome_reference_id_param INT(10),
 IN experiment_name_param VARCHAR(255),
 IN lines_crossed_param VARCHAR(255),
 IN founder_param VARCHAR(255),
 IN spike_mix_param ENUM('0', '1', '2'), 
 IN spike_dilution_param VARCHAR(255),
 IN spike_volume_param FLOAT,
 IN embryo_collection_method_param VARCHAR(255),
 IN embryos_collected_by_param VARCHAR(255),
 IN embryo_collection_date_param DATE,
 IN number_of_embryos_collected_param INT(10),
 IN collection_description_param ENUM('Blind', 'Phenotypic'),
 IN developmental_stage_id_param INT(10),
 IN description_param MEDIUMTEXT, 
 OUT exp_id int(10)
)
BEGIN 

INSERT INTO experiment (
 rna_extraction_id,
 image,
 study_id,
 genome_reference_id,
 name,
 lines_crossed,
 founder,
 spike_mix,
 spike_dilution,
 spike_volume,
 embryo_collection_method,
 embryo_collected_by,
 embryo_collection_date,
 number_embryos_collected,
 collection_description,
 developmental_stage_id,
 description
) 
VALUES ( 
 rna_extraction_id_param,
 image_param,
 study_id_param,
 genome_reference_id_param,
 experiment_name_param,
 lines_crossed_param,
 founder_param,
 spike_mix_param,
 spike_dilution_param,
 spike_volume_param,
 embryo_collection_method_param,
 embryos_collected_by_param,
 embryo_collection_date_param,
 number_of_embryos_collected_param,
 collection_description_param,
 developmental_stage_id_param,
 description_param
);
SET exp_id = LAST_INSERT_ID();
END$$
DELIMITER ;

/** adding excel file location and creation date to sequence_plate **/
DELIMITER $$
DROP PROCEDURE IF EXISTS update_excel_file_location_and_date$$

CREATE PROCEDURE update_excel_file_location_and_date (
 IN excel_report_file_location_param VARCHAR(255),
 IN excel_report_created_date_param DATE,
 IN plate_name_param VARCHAR(255)
)
BEGIN

 UPDATE sequence_plate  SET 
  excel_report_file_location  = excel_report_file_location_param,
  excel_report_created_date = excel_report_created_date_param
 WHERE plate_name = plate_name_param;

END$$
DELIMITER ;

/** library conc. excel file location to experiment **/
DELIMITER $$
DROP PROCEDURE IF EXISTS addLibFile$$

CREATE PROCEDURE addLibFile (
 IN exp_id_param INT(10),
 IN lib_file_loc_param VARCHAR(255)
)
BEGIN

 UPDATE experiment SET 
  library_conc_file = lib_file_loc_param
 WHERE id = exp_id_param;

END$$
DELIMITER ;

/** update sequence_plate table with library amount and volume **/
DELIMITER $$
DROP PROCEDURE IF EXISTS addLibAmts$$

CREATE PROCEDURE addLibAmts (
 IN exp_id_param INT(10),
 IN well_name_param VARCHAR(255),
 IN library_amount_param FLOAT,
 IN library_volume_param FLOAT,
 IN library_qc_param TINYINT(1)
)
BEGIN
 
 UPDATE sequence_plate seqp INNER JOIN rna_dilution_plate rdp 
 ON rdp.id = seqp.rna_dilution_plate_id INNER JOIN experiment exp 
 ON rdp.experiment_id = exp.id 
 SET seqp.library_amount = library_amount_param, 
     seqp.library_volume = library_volume_param, 
     seqp.library_qc = library_qc_param 
 WHERE exp.id = exp_id_param 
 AND seqp.well_name = well_name_param;

END$$
DELIMITER ;

/** update genotype table with comments **/
DELIMITER $$
DROP PROCEDURE IF EXISTS addGenotComments$$
 
CREATE PROCEDURE addGenotComments (
 IN exp_id_param INT(10),
 IN allele_name_param VARCHAR(255),
 IN geno_name_param VARCHAR(255),
 IN samp_comment_param MEDIUMTEXT  
)
BEGIN

UPDATE genotype gt INNER JOIN rna_dilution_plate rdp
 ON gt.rna_dilution_plate_id = rdp.id INNER JOIN experiment exp
 ON exp.id = rdp.experiment_id INNER JOIN allele alle
 ON alle.id = gt.allele_id
SET gt.sample_comment = samp_comment_param
WHERE alle.name = allele_name_param 
AND gt.name = geno_name_param
AND exp.id = exp_id_param;

END$$
DELIMITER ;

/** reset sample_comment field in genotype table **/
DELIMITER $$
DROP PROCEDURE IF EXISTS resetGenotComments$$

CREATE PROCEDURE resetGenotComments (
 IN exp_id_param INT(10)
)
BEGIN

UPDATE genotype gt INNER JOIN rna_dilution_plate rdp
 ON gt.rna_dilution_plate_id = rdp.id INNER JOIN experiment exp
 ON exp.id = rdp.experiment_id
SET gt.sample_comment = ""
WHERE exp.id = exp_id_param;

END$$
DELIMITER ;

/** updating sequence_plate cols sanger_plate_id and sanger_sample_id **/
DELIMITER $$
DROP PROCEDURE IF EXISTS update_sanger_plate_and_sample$$

CREATE PROCEDURE update_sanger_plate_and_sample (
 IN sanger_plate_id_param VARCHAR(255),
 IN sanger_sample_id_param VARCHAR(255),
 IN id_param INT(10)
)
BEGIN

 UPDATE sequence_plate  SET
  sanger_plate_id = sanger_plate_id_param,
  sanger_sample_id = sanger_sample_id_param
 WHERE id = id_param;

END$$
DELIMITER ;

/** updating an phenotype image **/
DELIMITER $$
DROP PROCEDURE IF EXISTS update_image$$

CREATE PROCEDURE update_image (
 IN experiment_id_param INT(10),
 IN image_param VARCHAR(255)
)
BEGIN

UPDATE experiment SET
 image = image_param
WHERE id = experiment_id_param;

END$$
DELIMITER ;

/** updating sequence_plate for wells which have been de-selected **/
DELIMITER $$
DROP PROCEDURE IF EXISTS updateSeqPlateSel$$

CREATE PROCEDURE updateSeqPlateSel (
 IN seq_id_param INT(10)
)
BEGIN

UPDATE sequence_plate SET
 selected = 0
WHERE id = seq_id_param;

END$$
DELIMITER ;

/** reset sequence_plate so that all wells are selected **/
DELIMITER $$
DROP PROCEDURE IF EXISTS resetSeqPlateSel$$

CREATE PROCEDURE resetSeqPlateSel (
 IN exp_id_param INT(10)
)
BEGIN

UPDATE sequence_plate seqp INNER JOIN rna_dilution_plate rdp
 ON seqp.rna_dilution_plate_id = rdp.id
 SET seqp.selected = 1,
     seqp.excel_report_created_date = NULL,
     seqp.excel_report_file_location = NULL 
 WHERE rdp.experiment_id = exp_id_param;

END$$
DELIMITER ;

