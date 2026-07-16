SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

NOMER_VERSION:=0.6.6
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NOMER_PROPERTIES_NAME:=target/name.properties
NOMER_PROPERTIES_PARSE:=target/parse.properties
NOMER_PROPERTIES_CORRECTED:=target/corrected.properties
NOMER_PROPERTIES_RETRY:=target/retry.properties
NOMER_PROPERTIES_ID2NAME:=target/id2name.properties
NOMER_PROPERTIES_NAME2ID:=target/name2id.properties

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

TAXON_CACHE_NAME:=$(BUILD_DIR)/taxonCache.tsv
TAXON_CACHE:=$(TAXON_CACHE_NAME).gz
TAXON_MAP_NAME:=$(BUILD_DIR)/taxonMap.tsv
TAXON_MAP:=$(TAXON_MAP_NAME).gz

VERBATIM_INTERACTIONS:=$(BUILD_DIR)/verbatim-interactions.tsv.gz

TAXONOMIES:=itis gbif indexfungorum discoverlife ncbi col pbdb tpt mdd batnames worms wikidata eol wfo


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
	cat config/parse.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_PARSE)
	cat config/corrected.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_CORRECTED)
	cat config/retry.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_RETRY)
	cat config/id2name.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_ID2NAME)
	cat config/name2id.properties <(${NOMER} properties | grep preston) > $(NOMER_PROPERTIES_NAME2ID)

resolve: update $(NOMER_JAR) $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update:
	cat $(NAMES) | gunzip | cut -f1,2,3 | sort | uniq | gzip > $(BUILD_DIR)/names_distinct.tsv.gz

	cat $(BUILD_DIR)/names_distinct.tsv.gz | gunzip | $(NOMER) append --include-header --properties=$(NOMER_PROPERTIES_NAME) $(TAXONOMIES) | gzip > $(BUILD_DIR)/names_appended.tsv.gz
	cat $(BUILD_DIR)/names_distinct.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_NAME) globi | grep -P "\t(FBC:FB|FBC:SLB)" | gzip >> $(BUILD_DIR)/names_appended.tsv.gz

	cat $(BUILD_DIR)/names_appended.tsv.gz | gunzip | grep -v "NONE" | sort | uniq | gzip > $(BUILD_DIR)/names_resolved.tsv.gz

	diff --changed-group-format='%<' --unchanged-group-format='' <(cat $(BUILD_DIR)/names_appended.tsv.gz | gunzip | grep "NONE" | cut -f1,2,3 | sort | uniq) <(cat $(BUILD_DIR)/names_appended.tsv.gz | gunzip | grep -v "NONE" | cut -f1,2,3 | sort | uniq) | gzip > $(BUILD_DIR)/names_unresolved.tsv.gz

	cat $(BUILD_DIR)/names_unresolved.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_PARSE) gbif-parse | gzip > $(BUILD_DIR)/names_parsed.tsv.gz
	cat $(BUILD_DIR)/names_unresolved.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_PARSE) globi-correct | $(NOMER) replace --properties=$(NOMER_PROPERTIES_CORRECT) gbif-parse | gzip >> $(BUILD_DIR)/names_parsed.tsv.gz

	cat $(BUILD_DIR)/names_parsed.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_RETRY) $(TAXONOMIES) | gzip > $(BUILD_DIR)/names_parsed_appended.tsv.gz
	cat $(BUILD_DIR)/names_parsed.tsv.gz | gunzip | $(NOMER) append --properties=$(NOMER_PROPERTIES_RETRY) globi | grep -P "\t(FBC:FB|FBC:SLB)" | gzip >> $(BUILD_DIR)/names_parsed_appended.tsv.gz

	cat $(BUILD_DIR)/names_parsed_appended.tsv.gz | gunzip | cut -f1,2,3,6- | grep -v NONE >> $(BUILD_DIR)/names_resolved.tsv.gz

	cat $(BUILD_DIR)/names_resolved.tsv.gz | gunzip | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|OCCURS_IN)" | cut -f5,6,8-12,14 | sed 's/$$/\t/g' | gzip > $(BUILD_DIR)/term_match.tsv.gz
	cat $(BUILD_DIR)/names_resolved.tsv.gz | gunzip | grep -P "(SAME_AS|SYNONYM_OF|HAS_ACCEPTED_NAME|COMMON_NAME_OF|OCCURS_IN)" | cut -f1,2,3,5,6,10 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz

	cat $(BUILD_DIR)/term_match.tsv.gz > $(TAXON_CACHE).update
	cat $(BUILD_DIR)/term_link_match.tsv.gz > $(TAXON_MAP).update

$(TAXON_CACHE):
	# swap working files with final result
	cat config/taxonCache.header.tsv.gz > $(BUILD_DIR)/term_header.tsv.gz
	cat config/taxonMap.header.tsv.gz > $(BUILD_DIR)/term_link_header.tsv.gz
	
	cat $(TAXON_CACHE).update | gunzip | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	cat $(TAXON_MAP).update | gunzip | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz
	
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
