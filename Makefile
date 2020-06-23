SHELL=/bin/bash
BUILD_DIR=target
STAMP=$(BUILD_DIR)/.$(BUILD_DIR)stamp

ELTON_VERSION:=0.9.11
ELTON_JAR:=$(BUILD_DIR)/elton.jar
ELTON:=java -jar $(BUILD_DIR)/elton.jar
ELTON_DATASET_DIR:=${BUILD_DIR}/datasets

NOMER_VERSION:=0.1.13
NOMER_JAR:=$(BUILD_DIR)/nomer.jar
NOMER:=java -jar $(NOMER_JAR)

NAMES:=$(BUILD_DIR)/names.tsv.gz
LINKS:=$(BUILD_DIR)/links.tsv.gz

TAXON_GRAPH_URL_PREFIX:=https://zenodo.org/record/3905244/files

TAXON_CACHE_NAME:=$(BUILD_DIR)/taxonCache.tsv
TAXON_CACHE:=$(TAXON_CACHE_NAME).gz
TAXON_MAP_NAME:=$(BUILD_DIR)/taxonMap.tsv
TAXON_MAP:=$(TAXON_MAP_NAME).gz

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

$(NAMES): $(ELTON_JAR)
	#$(ELTON) update --cache-dir=$(ELTON_DATASET_DIR)
	$(ELTON) names --cache-dir=$(ELTON_DATASET_DIR) | cut -f1-7 | gzip > $(BUILD_DIR)/globi-names.tsv.gz
	zcat $(BUILD_DIR)/globi-names.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/globi-names-sorted.tsv.gz
	mv $(BUILD_DIR)/globi-names-sorted.tsv.gz $(NAMES)

update: $(NAMES)

$(NOMER_JAR):
	wget -q "https://github.com/globalbioticinteractions/nomer/releases/download/$(NOMER_VERSION)/nomer.jar" -O $(NOMER_JAR)

$(BUILD_DIR)/term_link.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonMap.tsv.gz" -O $(BUILD_DIR)/term_link.tsv.gz

$(BUILD_DIR)/term.tsv.gz:
	wget -q "$(TAXON_GRAPH_URL_PREFIX)/taxonCache.tsv.gz" -O $(BUILD_DIR)/term.tsv.gz

resolve: update $(NOMER_JAR) $(BUILD_DIR)/term_link.tsv.gz $(TAXON_CACHE).update $(TAXON_MAP).update

$(TAXON_CACHE).update:
	cat $(BUILD_DIR)/term_link.tsv.gz | gunzip | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_link_names_sorted.tsv
	zcat $(NAMES) | cut -f1,2 | sort | uniq > $(BUILD_DIR)/names_sorted.tsv
        # remove likely non-names (e.g., 1950-07-17 | Mecosta | Michigan)
	diff --changed-group-format='%>' --unchanged-group-format='' $(BUILD_DIR)/term_link_names_sorted.tsv $(BUILD_DIR)/names_sorted.tsv | grep -v -E "([|]+.*){2}" | gzip > $(BUILD_DIR)/names_new.tsv.gz

	zcat $(BUILD_DIR)/names_new.tsv.gz | $(NOMER) append globi-correct | cut -f1,2,4,5 | sort | uniq | gzip > $(BUILD_DIR)/names_new_corrected.tsv.gz
	zcat $(BUILD_DIR)/names_new_corrected.tsv.gz | $(NOMER) append --properties=config/corrected.properties globi-enrich | gzip > $(BUILD_DIR)/term_resolved.tsv.gz
	zcat $(BUILD_DIR)/names_new_corrected.tsv.gz | $(NOMER) append --properties=config/corrected.properties globi-globalnames | gzip >> $(BUILD_DIR)/term_resolved.tsv.gz

	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF)" | cut -f6-14 | gzip > $(BUILD_DIR)/term_match.tsv.gz
	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep -v "NONE" | grep -P "(SAME_AS|SYNONYM_OF)" | cut -f1,2,6,7 | gzip > $(BUILD_DIR)/term_link_match.tsv.gz
	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep "NONE" | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_unresolved_once.tsv
	zcat $(BUILD_DIR)/term_link_match.tsv.gz | cut -f1,2 | sort | uniq > $(BUILD_DIR)/term_resolved_once.tsv
	diff --changed-group-format='%>' --unchanged-group-format='' $(BUILD_DIR)/term_resolved_once.tsv $(BUILD_DIR)/term_unresolved_once.tsv | gzip > $(BUILD_DIR)/term_unresolved.tsv.gz

	zcat $(BUILD_DIR)/term_resolved.tsv.gz | grep "SIMILAR_TO" | sort | uniq | gzip > $(BUILD_DIR)/term_fuzzy.tsv.gz

	# validate newly resolved terms and their links
	zcat $(BUILD_DIR)/term_match.tsv.gz | $(NOMER) validate-term | grep "all validations pass" | gzip > $(BUILD_DIR)/term_match_validated.tsv.gz
	zcat $(BUILD_DIR)/term_link_match.tsv.gz | $(NOMER) validate-term-link | grep "all validations pass" | gzip > $(BUILD_DIR)/term_link_match_validated.tsv.gz

	zcat $(BUILD_DIR)/term_link_match_validated.tsv.gz | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_MAP).update
	zcat $(BUILD_DIR)/term_match_validated.tsv.gz | grep -v "FAIL" | cut -f3- | gzip > $(TAXON_CACHE).update


$(TAXON_CACHE): $(BUILD_DIR)/term.tsv.gz
	# swap working files with final result
	zcat $(BUILD_DIR)/term.tsv.gz | tail -n +2 | gzip > $(BUILD_DIR)/term_no_header.tsv.gz
	zcat $(BUILD_DIR)/term.tsv.gz | head -n1 | gzip > $(BUILD_DIR)/term_header.tsv.gz
	
	zcat $(BUILD_DIR)/term_link.tsv.gz | tail -n +2 | gzip > $(BUILD_DIR)/term_link_no_header.tsv.gz
	zcat $(BUILD_DIR)/term_link.tsv.gz | head -n1 | gzip > $(BUILD_DIR)/term_link_header.tsv.gz
	
	zcat $(TAXON_CACHE).update $(BUILD_DIR)/term_no_header.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz
	zcat $(TAXON_MAP).update $(BUILD_DIR)/term_link_no_header.tsv.gz | sort | uniq | gzip > $(BUILD_DIR)/taxonMapNoHeader.tsv.gz

	cat $(BUILD_DIR)/term_link_header.tsv.gz $(BUILD_DIR)/taxonMapNoHeader.tsv.gz > $(TAXON_MAP)
	# normalize the ranks using nomer
	zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f3 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_ranks.tsv
	zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f7 | awk -F '\t' '{ print $$1 "\t" $$1 }' | $(NOMER) replace --properties=config/name2id.properties globi-taxon-rank | cut -f1 | $(NOMER) replace --properties=config/id2name.properties globi-taxon-rank > $(BUILD_DIR)/norm_path_ranks.tsv

	
	paste <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f1-2) <(cat $(BUILD_DIR)/norm_ranks.tsv) <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f4-6) <(cat $(BUILD_DIR)/norm_path_ranks.tsv) <(zcat $(BUILD_DIR)/taxonCacheNoHeader.tsv.gz | tail -n +2 | cut -f8-) | gzip > $(BUILD_DIR)/taxonCacheNorm.tsv.gz
	cat $(BUILD_DIR)/term_header.tsv.gz $(BUILD_DIR)/taxonCacheNorm.tsv.gz > $(TAXON_CACHE)

normalize: $(TAXON_CACHE)

$(TAXON_GRAPH_ARCHIVE): $(TAXON_CACHE)
	zcat $(TAXON_MAP) | sha256sum | cut -d " " -f1 > $(TAXON_MAP_NAME).sha256
	zcat $(TAXON_CACHE) | sha256sum | cut -d " " -f1 > $(TAXON_CACHE_NAME).sha256
	
	mkdir -p dist
	cp static/README static/prefixes.tsv $(TAXON_MAP) $(TAXON_MAP_NAME).sha256 $(TAXON_CACHE) $(TAXON_CACHE_NAME).sha256 dist/	
	
	zcat $(TAXON_MAP) | head -n11 > dist/taxonMapFirst10.tsv
	zcat $(TAXON_CACHE) | head -n11 > dist/taxonCacheFirst10.tsv

	cat $(BUILD_DIR)/names_sorted.tsv | gzip > dist/names.tsv.gz
	zcat dist/names.tsv.gz | sha256sum | cut -d " " -f1 > dist/names.tsv.sha256
	cp $(BUILD_DIR)/term_unresolved.tsv.gz dist/namesUnresolved.tsv.gz
	zcat dist/namesUnresolved.tsv.gz | sha256sum | cut -d " " -f1 > dist/namesUnresolved.tsv.sha256
 
	cd dist && zip taxon-graph.zip README taxonMap* taxonCache* names* prefixes.tsv
		
	
package: $(TAXON_GRAPH_ARCHIVE)
