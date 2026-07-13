SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

NOMER_VERSION:=0.6.6
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NOMER_PROPERTIES_NAME:=target/name.properties
NOMER_PROPERTIES_CORRECTED:=target/corrected.properties
NOMER_PROPERTIES_ID2NAME:=target/id2name.properties
NOMER_PROPERTIES_NAME2ID:=target/name2id.properties
NOMER_PROPERTIES_RESOLVED_ID_ONLY:=target/resolved-id-only.properties

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

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
	rm -rf $(BUILD_DIR)/* $(DIST_DIR)/* ${PWD}/.cache/nomer .nomer/*

$(STAMP):
	mkdir -p $(BUILD_DIR) && touch $@

$(VERBATIM_INTERACTIONS): $(STAMP)
	wget -q "https://depot.globalbioticinteractions.org/snapshot/target/data/tsv/verbatim-interactions.tsv.gz" -O $(VERBATIM_INTERACTIONS)

$(NAMES): $(VERBATIM_INTERACTIONS)
	cat $(VERBATIM_INTERACTIONS) | gunzip | mlr --tsvlite cut -f sourceTaxonId,sourceTaxonName,sourceTaxonPathNames | tail -n+2 | sort | uniq | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	cat $(VERBATIM_INTERACTIONS) | gunzip | mlr --tsvlite cut -f targetTaxonId,targetTaxonName,targetTaxonPathNames | tail -n+2 | sort | uniq | gzip >> $(BUILD_DIR)/globi-names.tsv.gz
	cat $(BUILD_DIR)/globi-names.tsv.gz | gunzip | sort | uniq | gzip > $(BUILD_DIR)/globi-names-sorted.tsv.gz
	mv $(BUILD_DIR)/globi-names-sorted.tsv.gz $(NAMES)

update: $(NAMES)

$(NOMER_JAR):
	wget -q "https://github.com/globalbioticinteractions/nomer/releases/download/$(NOMER_VERSION)/nomer.jar" -O $(NOMER_JAR)
	cat config/name.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_NAME)
	cat config/corrected.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_CORRECTED)
	cat config/id2name.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_ID2NAME)
	cat config/name2id.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_NAME2ID)
	cat config/resolved-id-only.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_RESOLVED_ID_ONLY)
	

resolve: update $(NOMER_JAR) $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update:
	cat $(NAMES) | gunzip | cut -f1,2,3 | sort | uniq | gzip > $(BUILD_DIR)/names_new.tsv.gz

	cat $(BUILD_DIR)/names_new.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) globi-correct | cut -f1,2,3,5,6,10 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz

	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) globi | grep -P "\t(FBC:FB|FBC:SLB)" | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) gbif | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) pbdb | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) tpt | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) mdd | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) worms | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) wikidata | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) eol | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_once.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2,3 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	mv $(BUILD_DIR)/term_resolved_once.tsv.gz $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once.tsv | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) gbif-parse | cut -f1,2,3,5,6,10 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz

	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) itis | grep -P "\t(FBC:FB|FBC:SLB)" | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
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
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) worms | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) wikidata | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) eol | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_twice.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2,3 | sort | uniq > $(BUILD_DIR)/term_unresolved_twice.tsv
	mv $(BUILD_DIR)/term_resolved_twice.tsv.gz $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice.tsv | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) globi-correct | cut -f1,2,3,5,6,10 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz

	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) globi | grep -P "\t(FBC:FB|FBC:SLB)" | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) itis | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) discoverlife | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) ncbi | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) col | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) gbif | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) indexfungorum | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) pbdb | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) tpt | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) mdd | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) batnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) worms | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) wikidata | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/term_unresolved_twice_corrected.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_CORRECTED) eol | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz


	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|OCCURS_IN)" | cut -f8,9,11-15,17 | sed 's/$$/\t/g' | gzip > $(BUILD_DIR)/term_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|OCCURS_IN)" | cut -f1,2,3,8,9,10 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2,3 | sort | uniq > $(BUILD_DIR)/term_unresolved_twice.tsv
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | cut -f1,2,3 | sort | uniq > $(BUILD_DIR)/term_resolved_twice.tsv

	cat $(BUILD_DIR)/term_match.tsv.gz > $(TAXON_CACHE).update
	cat $(BUILD_DIR)/term_link_match.tsv.gz > $(TAXON_MAP).update

$(TAXON_CACHE):
	# swap working files with final result
	cat config/taxonCache.header.tsv.gz > $(BUILD_DIR)/term_header.tsv.gz
	cat config/taxonMap.header.tsv.gz > $(BUILD_DIR)/term_link_header.tsv.gz
	
	cat $(TAXON_CACHE).update > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	cat $(TAXON_MAP).update > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz
	
	# integrate with wikidata via taxon identifiers only 
	cat $(BUILD_DIR)/taxonMapNoHeader.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_RESOLVED_ID_ONLY) wikidata | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_with_wikidata.tsv.gz
	cat $(BUILD_DIR)/term_resolved_with_wikidata.tsv.gz | gunzip | cut -f1-3,8,9,13 | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeaderWDOnly.tsv.gz
	cat $(BUILD_DIR)/term_resolved_with_wikidata.tsv.gz | gunzip | cut -f8- | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNoHeadeWDOnly.tsv.gz
	cat $(BUILD_DIR)/taxonMapNoHeader.tsv.gz $(BUILD_DIR)/taxonMapNoHeaderWDOnly.tsv.gz > $(BUILD_DIR)/taxonMapNoHeaderWDAppended.tsv.gz
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz $(BUILD_DIR)/taxonCacheNoHeaderWDOnly.tsv.gz > $(BUILD_DIR)/taxonCacheNoHeaderWDAppended.tsv.gz
	
	cat $(BUILD_DIR)/taxonCacheNoHeaderWDAppended.tsv.gz > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	cat $(BUILD_DIR)/taxonMapNoHeaderWDAppended.tsv.gz > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz
	
	# pre-index globi-taxon-rank index if needed (workaround for https://github.com/globalbioticinteractions/nomer/issues/183)
	echo -e "\tsoort" | ${NOMER} append globi-taxon-rank

	# normalize the ranks using nomer
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 > $(BUILD_DIR)/norm_ranks_tmp.tsv
	cat $(BUILD_DIR)/norm_ranks_tmp.tsv | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 > $(BUILD_DIR)/norm_path_ranks_tmp.tsv
	cat $(BUILD_DIR)/norm_path_ranks_tmp.tsv | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv

	
	paste <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f1-2) <(cat $(BUILD_DIR)/norm_ranks.tsv) <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f4-6) <(cat $(BUILD_DIR)/norm_path_ranks.tsv) <(cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f8-) | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNorm.tsv.gz

	# prepend header	
	cat $(BUILD_DIR)/term_link_header.tsv.gz $(BUILD_DIR)/taxonMapNoHeader.tsv.gz > $(TAXON_MAP)
	cat $(BUILD_DIR)/term_header.tsv.gz $(BUILD_DIR)/taxonCacheNorm.tsv.gz > $(TAXON_CACHE)

normalize: $(TAXON_CACHE)

$(TAXON_GRAPH_ARCHIVE): $(TAXON_CACHE)
	cat $(TAXON_MAP) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_MAP_NAME).sha256
	cat $(TAXON_CACHE) | gunzip | sha256sum | cut -d " " -f1 > $(TAXON_CACHE_NAME).sha256
	
	mkdir -p dist
	cp static/README static/prefixes.tsv $(TAXON_MAP) $(TAXON_MAP_NAME).sha256 $(TAXON_CACHE) $(TAXON_CACHE_NAME).sha256 dist/
	
	cat $(TAXON_MAP) | gunzip | head -n11 > dist/taxonMapFirst10.tsv
	cat $(TAXON_CACHE) | gunzip | head -n11 > dist/taxonCacheFirst10.tsv

	cat $(NAMES) > dist/names.tsv.gz
	cat dist/names.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/names.tsv.sha256

	diff --changed-group-format='%<' --unchanged-group-format='' <(cat dist/names.tsv.gz | gunzip | cut -f1,2,3 | sort | uniq) <(cat dist/taxonMap.tsv.gz | gunzip | tail -n+2 | cut -f1,2,3 | sort | uniq) | gzip > dist/namesUnresolved.tsv.gz

	cat dist/namesUnresolved.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/namesUnresolved.tsv.sha256
	
package: $(TAXON_GRAPH_ARCHIVE)
