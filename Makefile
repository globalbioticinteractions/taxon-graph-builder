SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

NOMER_VERSION:=0.5.10
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NOMER_PROPERTIES_CORRECTED:=target/corrected.properties
NOMER_PROPERTIES_ID2NAME:=target/id2name.properties
NOMER_PROPERTIES_NAME2ID:=target/name2id.properties

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
	rm -rf $(BUILD_DIR)/* $(DIST_DIR)/* .nomer/*

$(STAMP):
	mkdir -p $(BUILD_DIR) && touch $@

$(VERBATIM_INTERACTIONS): $(STAMP)
	wget -q "https://depot.globalbioticinteractions.org/snapshot/target/data/tsv/verbatim-interactions.tsv.gz" -O $(VERBATIM_INTERACTIONS)

$(NAMES): $(VERBATIM_INTERACTIONS)
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

resolve: update $(NOMER_JAR) $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update:
	cat $(NAMES) | gunzip | cut -f1,2 | sort | uniq | gzip > $(BUILD_DIR)/names_new.tsv.gz

	cat $(BUILD_DIR)/names_new.tsv.gz | gunzip | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz

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
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append worms | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz
	cat $(BUILD_DIR)/names_new_corrected.tsv.gz | gunzip | $(NOMER) append wfo | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | gzip > $(BUILD_DIR)/term_resolved_once.tsv.gz
	mv $(BUILD_DIR)/term_resolved_once.tsv.gz $(BUILD_DIR)/term_resolved.tsv.gz

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	cat $(BUILD_DIR)/term_unresolved_once.tsv | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/term_unresolved_once_corrected.tsv.gz

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

	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF)" | cut -f6,7,9-13,15 | sed 's/$$/\t/g' | gzip > $(BUILD_DIR)/term_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF)" | cut -f1,2,6,7 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	cat $(BUILD_DIR)/term_resolved.tsv.gz | gunzip | grep "NONE" | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	cat $(BUILD_DIR)/term_link_match.tsv.gz | gunzip | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_resolved_once.tsv

	cat $(BUILD_DIR)/term_match.tsv.gz > $(TAXON_CACHE).update
	cat $(BUILD_DIR)/term_link_match.tsv.gz > $(TAXON_MAP).update

$(TAXON_CACHE):
	# swap working files with final result
	cat config/taxonCache.header.tsv.gz > $(BUILD_DIR)/term_header.tsv.gz
	cat config/taxonMap.header.tsv.gz > $(BUILD_DIR)/term_link_header.tsv.gz
	
	cat $(TAXON_CACHE).update > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	cat $(TAXON_MAP).update > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz

	# normalize the ranks using nomer
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	cat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | gunzip | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=$(NOMER_PROPERTIES_NAME2ID) globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=$(NOMER_PROPERTIES_ID2NAME) globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv

	
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

	diff --changed-group-format='%<' --unchanged-group-format='' <(cat dist/names.tsv.gz | gunzip | cut -f1,2 | sort | uniq) <(cat dist/taxonMap.tsv.gz | gunzip | tail -n+2 | cut -f1,2 | sort | uniq) | gzip > dist/namesUnresolved.tsv.gz

	cat dist/namesUnresolved.tsv.gz | gunzip | sha256sum | cut -d " " -f1 > dist/namesUnresolved.tsv.sha256
	
package: $(TAXON_GRAPH_ARCHIVE)
