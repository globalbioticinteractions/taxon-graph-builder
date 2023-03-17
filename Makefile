SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

ELTON_VERSION:=0.12.6
ELTON_JAR:=$(BUILD_DIR)/elton.jar
ELTON:=java -jar $(BUILD_DIR)/elton.jar
ELTON_DATASET_DIR:=${BUILD_DIR}/datasets

NOMER_VERSION:=0.4.11
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NOMER_PROPERTIES_CORRECTED:=target/corrected.properties
NOMER_PROPERTIES_NCBI_REMATCH:=target/ncbi-rematch.properties
NOMER_PROPERTIES_ID2NAME:=target/id2name.properties
NOMER_PROPERTIES_NAME2ID:=target/name2id.properties

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

TAXON_GRAPH_URL_PREFIX:=https://zenodo.org/record/6394935/files

TAXON_CACHE_NAME:=$(BUILD_DIR)/taxonCache.tsv
TAXON_CACHE:=$(TAXON_CACHE_NAME).gz
TAXON_MAP_NAME:=$(BUILD_DIR)/taxonMap.tsv
TAXON_MAP:=$(TAXON_MAP_NAME).gz

VERBATIM_INTERACTIONS:=$(BUILD_DIR)/verbatim-interactions.tsv.gz

DIST_DIR:=dist
TAXON_GRAPH_ARCHIVE:=$(DIST_DIR)/taxon-graph.zip

.PHONY: all clean update resolve normalize package

all: update resolve normalize package

clean:
	rm -rf $(BUILD_DIR)/* $(DIST_DIR)/* .nomer/*

$(STAMP):
	mkdir -p $(BUILD_DIR) && touch $@

$(ELTON_JAR): $(STAMP)
	wget -q "https://github.com/globalbioticinteractions/elton/releases/download/$(ELTON_VERSION)/elton.jar" -O $(ELTON_JAR)

$(VERBATIM_INTERACTIONS): $(STAMP)
	wget -q "https://depot.globalbioticinteractions.org/snapshot/target/data/tsv/verbatim-interactions.tsv.gz" -O $(VERBATIM_INTERACTIONS)

$(NAMES): $(VERBATIM_INTERACTIONS)
	#$(ELTON) update --cache-dir=$(ELTON_DATASET_DIR)
	#$(ELTON) names --cache-dir=$(ELTON_DATASET_DIR) | tail -n+2 | cut -f1-7 | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	cat $(VERBATIM_INTERACTIONS) | gunzip | mlr --tsvlite cut -f sourceTaxonId,sourceTaxonName | tail -n+2 | sort | uniq | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	cat $(VERBATIM_INTERACTIONS) | gunzip | mlr --tsvlite cut -f targetTaxonId,targetTaxonName | tail -n+2 | sort | uniq | gzip >> $(BUILD_DIR)/globi-names.tsv.gz
	cat $(BUILD_DIR)/globi-names.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/globi-names-sorted.tsv.gz
	mv $(BUILD_DIR)/globi-names-sorted.tsv.gz $(NAMES)

update: $(NAMES)

$(NOMER_JAR):
	wget -q "https://github.com/globalbioticinteractions/nomer/releases/download/$(NOMER_VERSION)/nomer.jar" -O $(NOMER_JAR)
	cat config/corrected.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_CORRECTED)
	cat config/id2name.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_ID2NAME)
	cat config/name2id.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_NAME2ID)
	cat config/ncbi-rematch.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_NCBI_REMATCH)

$(BUILD_DIR)/term_link.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonMap.tsv.gz" -O $(BUILD_DIR)/term_link.tsv.gz

$(BUILD_DIR)/term.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonCache.tsv.gz" -O $(BUILD_DIR)/term.tsv.gz

$(BUILD_DIR)/namesUnresolved.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/namesUnresolved.tsv.gz" -O $(BUILD_DIR)/namesUnresolved.tsv.gz

resolve: update $(NOMER_JAR) $(BUILD_DIR)/term_link.tsv.gz $(BUILD_DIR)/namesUnresolved.tsv.gz $(TAXON_CACHE).update $(TAXON_MAP).update

w$(TAXON_CACHE).update:
	cat $(NAMES) | gunzip | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/names_new.tsv.gz

	cat $(BUILD_DIR)/names_new.tsv.gz | gunzip | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz

	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append globi | gzip > $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append gbif | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append pbdb | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append tpt | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append mdd | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_once.tsv.gz
	mv $(BUILD_DIR)/term_resolved_once.tsv.gz $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	cat $(BUILD_DIR)/term_unresolved_once.tsv | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz

	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) globi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) gbif | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) pbdb | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) tpt | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) mdd | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME_OF|COMMON_NAME_OF)" | cut -f6-14 | gzip > $(BUILD_DIR)/term_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF)" | cut -f1,2,6,7 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_resolved_once.tsv


	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "SIMILAR_TO" | sort | uniq | gzip > $(BUILD_DIR)/term_fuzzy.tsv.gz

	# validate newly resolved terms and their links
	cat $(BUILD_DIR)/term_match.tsv.gz | gunzip | $(NOMER) validate-terms | grep "all validations pass" | gzip > $(BUILD_DIR)/term_match_validated.tsv.gz
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | $(NOMER) validate-term-link | grep "all validations pass" | gzip > $(BUILD_DIR)/term_link_match_validated.tsv.gz

	cat $(BUILD_DIR)/term_link_match_validated.tsv.gz | gunzip | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_MAP).update
	cat $(BUILD_DIR)/term_match_validated.tsv.gz | gunzip | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_CACHE).update


$(TAXON_CACHE): $(BUILD_DIR)/term.tsv.gz
	# swap working files with final result
	cat $(BUILD_DIR)/term.tsv.gz | gunzip | tail -n +2 | gzip > $(BUILD_DIR)/term_no_header.tsv.gz
	cat $(BUILD_DIR)/term.tsv.gz | gunzip | head -n1 | gzip > $(BUILD_DIR)/term_header.tsv.gz
	
	cat $(BUILD_DIR)/term_link.tsv.gz | gunzip | tail -n +2 | gzip > $(BUILD_DIR)/term_link_no_header.tsv.gz
	cat $(BUILD_DIR)/term_link.tsv.gz | gunzip | head -n1 | gzip > $(BUILD_DIR)/term_link_header.tsv.gz
	
	cat $(TAXON_CACHE).update $(BUILD_DIR)/term_no_header.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNoHeaderPart.tsv.gz
	cat $(TAXON_MAP).update $(BUILD_DIR)/term_link_no_header.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeaderPart.tsv.gz

	# only include NCBI taxon hierarchies via ncbi matcher to avoid including outcomes of https://github.com/GlobalNamesArchitecture/gni/issues/48
	cat $(BUILD_DIR)/taxonCacheNoHeaderPart.tsv.gz | gunzip | grep -v -E "^NCBI:" | grep -v -E "^OTT:" | gzip > $(BUILD_DIR)/taxonCacheNoHeaderNoNCBI.tsv.gz
	cat $(BUILD_DIR)/taxonMapNoHeaderPart.tsv.gz | gunzip | grep -P "\tNCBI:" | ${NOMER} append --properties=$(NOMER_PROPERTIES_NCBI_REMATCH) ncbi | grep -v "NONE" | gzip > ${BUILD_DIR}/taxonMapNoHeaderMatchNCBIAgain.tsv.gz
	cat $(BUILD_DIR)/taxonMapNoHeaderPart.tsv.gz | gunzip | grep -v -P "\tNCBI:" | grep -v -P "\tOTT:" | gzip > $(BUILD_DIR)/taxonMapNoHeaderNoNCBI.tsv.gz
	cat ${BUILD_DIR}/taxonMapNoHeaderMatchNCBIAgain.tsv.gz | gunzip | cut -f1,2,6,7 | gzip > ${BUILD_DIR}/taxonMapNoHeaderWithNCBI.tsv.gz
	cat ${BUILD_DIR}/taxonMapNoHeaderMatchNCBIAgain.tsv.gz | gunzip | cut -f6-14 | gzip > ${BUILD_DIR}/taxonCacheNoHeaderWithNCBI.tsv.gz

	cat $(BUILD_DIR)/taxonMapNoHeaderNoNCBI.tsv.gz $(BUILD_DIR)/taxonMapNoHeaderWithNCBI.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeaderWithAll.tsv.gz
	cat $(BUILD_DIR)/term_link_header.tsv.gz $(BUILD_DIR)/taxonMapNoHeaderWithAll.tsv.gz > $(TAXON_MAP)

	cat ${BUILD_DIR}/taxonCacheNoHeaderNoNCBI.tsv.gz ${BUILD_DIR}/taxonCacheNoHeaderWithNCBI.tsv.gz > ${BUILD_DIR}/taxonCacheNoHeader.tsv.gz
	# normalize the ranks using nomer
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | tail -n +2 | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | tail -n +2 | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv

	
	paste <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | tail -n +2 | cut -f1-2) <(cat $(BUILD_DIR)/norm_ranks.tsv) <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | tail -n +2 | cut -f4-6) <(cat $(BUILD_DIR)/norm_path_ranks.tsv) <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | tail -n +2 | cut -f8-) | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNorm.tsv.gz
	cat $(BUILD_DIR)/term_header.tsv.gz $(BUILD_DIR)/taxonCacheNorm.tsv.gz > $(TAXON_CACHE)

normalize: $(TAXON_CACHE)

$(TAXON_GRAPH_ARCHIVE): $(TAXON_CACHE)
	cat $(TAXON_MAP) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_MAP_NAME).sha256
	cat $(TAXON_CACHE) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_CACHE_NAME).sha256
	
	mkdir -p dist
	cp static/README static/prefixes.tsv $(TAXON_MAP) $(TAXON_MAP_NAME).sha256 $(TAXON_CACHE) $(TAXON_CACHE_NAME).sha256 dist/
	
	cat $(TAXON_MAP) | gunzip | head -n11 > dist/taxonMapFirst10.tsv
	cat $(TAXON_CACHE) | gunzip | head -n11 > dist/taxonCacheFirst10.tsv

	cat $(BUILD_DIR)/names_sorted.tsv | gzip > dist/names.tsv.gz
	cat dist/names.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/names.tsv.sha256

	diff --changed-group-format='%<' --unchanged-group-format='' <(cat dist/names.tsv.gz | gunzip | cut -f1,2 | sort | uniq) <(cat dist/taxonMap.tsv.gz | gunzip | tail -n+2 | cut -f1,2 | sort | uniq) | gzip > dist/namesUnresolved.tsv.gz

	cat dist/namesUnresolved.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/namesUnresolved.tsv.sha256
		
	
package: $(TAXON_GRAPH_ARCHIVE)
