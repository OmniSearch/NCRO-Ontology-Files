(def-uri-alias "definition" !obo:IAO_0000115)
(def-uri-alias "editornote" !obo:IAO_0000116)
(def-uri-alias "termeditor" !obo:IAO_0000117)
(def-uri-alias "definitionsource" !obo:IAO_0000119)
(def-uri-alias "onlyintaxon" !obo:RO_0002160)
(def-uri-alias "alternativeterm" !obo:IAO_0000118)

    
(defmethod species-for-prefix ((m mirbase) prefix)
  (second (assoc prefix '(("hsa" !obo:NCBITaxon_9606)
			  ("mmu" !obo:NCBITaxon_10090)
			  ("rno" !obo:NCBITaxon_10116)
			  ("gga" !obo:NCBITaxon_9031)
			  ("cel" !obo:NCBITaxon_6239)
			  ("cfa" !obo:NCBITaxon_9615)
			  ("dre" !obo:NCBITaxon_7955)
			  ("dan" !obo:NCBITaxon_7217)
			  ("der" !obo:NCBITaxon_7220)
			  ("dgr" !obo:NCBITaxon_7222)
			  ("dme" !obo:NCBITaxon_7227)
			  ("dmo" !obo:NCBITaxon_7230)
			  ("dpe" !obo:NCBITaxon_7234)
			  ("dps" !obo:NCBITaxon_7237)
			  ("dse" !obo:NCBITaxon_7238)
			  ("dsi" !obo:NCBITaxon_7240)
			  ("dvi" !obo:NCBITaxon_7244)
			  ("dwi" !obo:NCBITaxon_7260)
			  ("dya" !obo:NCBITaxon_7245))
		 :test 'equal)))
  
(defmethod uri-for-accession ((m mirbase) accession)
  (make-uri (format nil "http://purl.obolibrary.org/NCRO_~a" accession)))


The issue here is how to align what is wanted (as best I can guess)
from NCRO and the work that has been done already, primary the
associate with miRBase. Currently the dxref is to miRBase records that
appear to denote pri-miRNA. I conclude this because the sequences
given include the intact stem-loop and because miRBase has different
entries for mature miRNA (the MIMATxxx records). While pri-miRNA are
polytadenylated, it is common to omit this from the sequence.

NCRO initially mixes these records. We have, for example,

hsa-miR-125b-5p (mature - MIMAT) MIMAT0000423 from hsa-miR-125b-1 (this should really be called  hsa-miR-125b-1-5p )
hsa-miR-125b-1-3p (mature - MIMAT) MIMAT0004592 from hsa-miR-125b-1
hsa-miR-125b-2-3p (mature - MIMAT) MIMAT0004603 from hsa-miR-125b-2
hsa-miR-125b-1 (stem loop - MI0) MI0000446
hsa-miR-125b-2 (stem loop) - MI0) MI0000470


It also has
mir-10 MIPF0000033 - the family that includes the above

mir-10 is related to , hsa-miR-125b-1 and hsa-miR-125b-2 via
is_about_grouped_miRNA

The mature forms are not related to the stem loops in the original.

Since both stem loops and mature are present in NCRO (albeit not well
distinguished) we should include both, with a derived-from link from
mature to pri. (derivation is transitive)

Now families. The question is whether the families are computational
artifacts or evolutionary relationship. From reading the paper it
seems that they are intended to be evolutionary, even though they may
be determined to be such by sequence alignment. So we will have
families be superclasses (ala cross-species in PRO) with evidence
coming from the algorithm application.

Finally, there is the question of whether to represent the sequences.
Since the mature miRNA's are unambiguous it seems that might be a good
idea. What is the relation to the molecules? Concretization? The
sequences are individuals.

What should the definitions be?

The gene products should mention the gene. We don't have an ontology
of genes. We'll name the gene symbol when we have one.  The final
products are the mature sequences. We can name them in the
definition. We do have the chromosome positions - we could use that.

The stem loop definitions can either include or not include the sequence.q

The mature miRNA should be identified by the sequence which we can
name in the definition.

The families can be named by the human gene - blah or orthologous to
blah.



;; human, mouse, rat, c-elegams, dros, dog, cow, chicken, zfin
(defmethod human-or-model-in-human-family ((m mirbase) entry)
  (let* ((name (getf entry :name)))
    (or (#"matches" name "hsa-.*")
	(and (#"matches" name "^(mmu|rno|d|cel|cfa|gga|dre)-.*")
	     (let ((fam (gethash (#"replace" (getf entry :accession) ";" "") (member2family m))))
	       (find-if (lambda(el) (#"matches" (getf (gethash (concatenate 'string el ";") (entries m)) :name) "hsa.*")) (gethash fam (family2member m))))))))

(defmethod human-entry ((m mirbase) entry)
  (let* ((name (getf entry :name)))
    (#"matches" name "hsa-.*")))

;; print out and count the mirna to include
(defmethod debug-which-to-include ((m mirbase))
  (let ((count 0))(maphash 
   (lambda(accession entry) ;; iterate over stem loops
     (when (human-or-model-in-human-family m entry)
       (print (getf entry :name)) (incf count)))
     (entries m)) count))

(defmethod axioms-for-family ((m mirbase) human-entry family-accession)
  (let ((subject (uri-for-accession m family-accession))
	(gene (gethash (#"replace" (getf human-entry :accession) ";" "") (accession2gene m)))
	(mirna-gene-product !obo:NCRO_0004019))
    (list*
     `(declaration (class ,subject))
     `(subclassof ,subject ,mirna-gene-product)
     `(annotation-assertion !foaf:page ,subject ,(make-uri (format nil "http://www.mirbase.org/cgi-bin/mirna_summary.pl?fam=~a" family-accession)))
     `(annotation-assertion !rdfs:label ,subject (format nil "miRNA family ~a" (gethash family-accession (accession2name m))))
     `(annotation-assertion !definition ,subject
		  ,(format nil "A miRNA gene product of human gene ~a on chromosome ~a at approximately position ~a-~a, or ortholog therof"
			   (third (getf human-entry :gene))
			   (#"replace" (first gene) "chr" "") (second gene) (third gene)))
     `(annotation-assertion !alternativeterm ,subject ,family-accession)
     (loop for member in (gethash family-accession (family2member m))
	for entry = (gethash (concatenate 'string member ";") (entries m))
	when (human-or-model-in-human-family m entry)
	collect
	  `(subclassof ,(uri-for-accession m member) ,subject)))))

(defmethod axioms-for-pri-mirna ((m mirbase) entry)
  (let ((subject (uri-for-accession m (getf entry :accession)))
	(gene (gethash (#"replace" (getf entry :accession) ";" "") (accession2gene m)))
	(primary-mirna !obo:NCRO_0004018))
    (list*
     `(declaration (class ,subject))
     `(annotation-assertion !rdfs:label (getf entry :longname))
     (if (getf entry :description)
	 `(annotation-assertion !!editor-note ,subject (getf entry :description)))
     `(subclassof ,subject ,primary-mirna)
     `(annotation-assertion !foaf:page ,subject ,(make-uri (format nil "http://www.mirbase.org/cgi-bin/mirna_entry.pl?acc=" (getf entry :accession))))
     `(annotation-assertion !definition ,subject
			    ,(format nil "A miRNA gene product that is the primary transcript of human gene ~a"
				     (third gene)))
     `(subclass-of ,subject (object-some-values-from !onlyintaxon ,(species-for-prefix m (subseq (getf entry :name) 0 3))))
     `(annotation-assertion !alternativeterm ,subject ,(getf entry :accession))
     )))


(defmethod axioms-for-matures ((m mirbase) entry)
  (let ((pri-mirna-uri  (uri-for-accession m (getf entry :accession))))
    (loop for mature in (getf entry :matures)
       for sequence = (second (assoc :sequence mature))
       for name = (second (assoc :product mature))
       for accession = (second (assoc :accession mature))
       for subject = (uri-for-accession m accession)
       collect
	 (list
	  `(declaration (class ,subject))
	  `(annotation-assertion !rdfs:label ,subject  ,name)
	  `(subclassof ,subject ,pri-mirna-uri)
	  `(annotation-assertion !foaf:page ,subject ,(make-uri (format nil "http://www.mirbase.org/cgi-bin/mature.pl?mature_acc=~a" accession)))
	  `(annotation-assertion !definition ,subject
				 ,(format nil "A mature miRNA with sequence ~a" sequence))
	  `(subclass-of ,subject (object-some-values-from !onlyintaxon ,(species-for-prefix (subseq (getf entry :name) 0 3))))
	  `(annotation-assertion !alternativeterm ,subject ,accession)))))


(defmethod generate-mirbase-owl ((m mirbase))
  (with-ontology mirna (:collecting t)
      ((asq (imports !obo:ncro.owl))
       (maphash 
	(lambda(accession entry) ;; iterate over stem loops
	  (when (human-or-model-in-human-family m entry)
	    (as (axioms-for-pri-mirna m entry))
	    (as (axioms-for-matures m entry))
	    (when (human-entry m entry)
	      (as (axioms-for-family m entry (gethash (getf entry :accession) (member2family m)))))))
	(entries m)))))