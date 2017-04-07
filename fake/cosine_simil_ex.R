library(tidyverse)
library(tidytext)
library(stringr)
library(SnowballC) #for stemming.. dont need if dont want to stem
########################################
# prep data
########################################
doc_df <- tibble(id=c(1,1,1,1,1,1,1,2,2,3,4),
                 text = c("This", "document", "has","one","word","per","row",
                 "This document has", "two rows total",
                 "This document has only one measely row",
                 "This document has only one measely row")) %>% 
  mutate(id=as.character(id))

########################################
# pairwise cosine simil of all rows in a df
########################################
dtm_df <- doc_df %>% 
  create_dtm(id, #create_dtm func def at bottom of script
             text,
             stem="SnowballC::wordStem", 
             stopwords=NULL)

#drop id and convert to matrix
dtm_mat <- dtm_df %>% 
  select(-id) %>% 
  as.matrix()

#create all possible combos of ids; calc rowwise simil and bind to ids; transpose; restructure
pairwise_row_cos_simil <- combn(dtm_df$id,2) %>% 
  rbind(lexRankr:::idfCosineSimil(dtm_mat)) %>% #implemented in C++  ᕦ( ͡° ͜ʖ ͡°)ᕤ
  t() %>% 
  as_data_frame() %>% 
  set_names(c("id_1","id_2","cosine_simil")) %>% 
  mutate(cosine_simil = as.numeric(cosine_simil))
# # A tibble: 6 × 3
#    id_1  id_2 cosine_simil
#   <chr> <chr>        <dbl>
# 1     1     2    0.6172134
# 2     1     3    0.7142857
# 3     1     4    0.7142857
# 4     2     3    0.6172134
# 5     2     4    0.6172134
# 6     3     4    1.0000000

########################################
# compare each doc to a single doc of interest
########################################
doc_of_interest <- c("how", "close", "are", "documents", "to", "this", "one") %>% 
  tibble(id="uhhh", text=.)

#create dtm with doc of interest included in case of differing
#    vocab between interest & other doc corpus
dtm_df2 <- doc_df %>% 
  bind_rows(doc_of_interest) %>% 
  create_dtm(id,#create_dtm func def at bottom of script
             text,
             stem="SnowballC::wordStem", 
             stopwords=NULL)

#extract doc of interest row in dtm to vector
doc_of_interest_vec <- dtm_df2 %>% 
  filter(id == "uhhh") %>% 
  select(-id) %>% 
  unlist()

#drop doc of interest row from dtm_df and call function 
#    to compare all rows in dtm to doc of interest vec
simil_to_interest <- dtm_df2 %>% 
  filter(id != "uhhh") %>% 
  row_cosine_simil(doc_of_interest_vec, #row_cosine_simil func def at bottom of script
                   out_col = "simil_to_interest", 
                   drop_cols = "id") %>% 
  select(id, simil_to_interest)
# # A tibble: 4 × 2
#      id simil_to_interest
#   <chr>             <dbl>
# 1     1         0.4285714
# 2     2         0.3086067
# 3     3         0.4285714
# 4     4         0.4285714
#-----------------------------------------------------------------------------------------

########################################
# helper functions
########################################
create_dtm  <- function(tbl, doc_id_col, text_col, stem="SnowballC::wordStem", stopwords=tidytext::stop_words$word) {
  #tbl:        document containting doc ids and text
  #doc_id_col: name of doc id column
  #text_col:   name of text column
  #stem:       function to stem text column (as character); set to NULL if dont want to stem
  #stopwords:  char vector of stopwords to remove; set to NULL if dont want rm stopwords
  
  doc_col_str  <- as.character(substitute(doc_id_col))
  txt_col_str  <- as.character(substitute(text_col))
  
  token_df <- tbl %>%
    tidytext::unnest_tokens_("token", txt_col_str) %>% 
    dplyr::select_(doc_col_str, "token") %>% 
    dplyr::distinct()
  
  if (is.character(stem)) {
    stem_func_call <- paste0(stem, "(token)")
    token_df <- token_df %>% 
      dplyr::mutate_("token" = stem_func_call) %>% 
      dplyr::distinct()
    
    if (is.character(stopwords)) {
      stem_stopwords <- eval(parse(text=paste0(stem,"(stopwords)")))
      stopwords      <- c(stem_stopwords, stopwords)
    }
  }
  
  if (is.character(stopwords)) {
    stop_words_str    <- paste0('c("',paste(stopwords, collapse='", "'),'")')
    stop_words_filter <- paste0("!token %in% ", stop_words_str)
    token_df <- token_df %>% 
      filter_(stop_words_filter)
  }
  
  dtm_df <- token_df %>% 
    dplyr::mutate_("bin" = 1) %>% 
    tidyr::spread_(key = "token", value = "bin", fill = 0)
  
  return(dtm_df)
}

#calculate cosine 
cosine_simil <- function(x, y) {
  #x: numeric vector with length == length(y)
  #y: numeric vector with length == length(x)
  if(sum(x) == 0 | sum(y) == 0) return(0)
  crossprod(x, y)/sqrt(crossprod(x) * crossprod(y))
}

row_cosine_simil <- function(tbl, vec, out_col="simil", drop_cols=NULL) {
  #tbl:       table with rows to be compared (using cosine simil) to vec
  #vec:       vector to compare (using cosine simil) to every row of tbl
  #out_col:   name of output column of simil values
  #drop_cols: char vector of columns not to be included in comparison of tbl rows to vec
  tbl_og <- tbl
  
  if(is.character(drop_cols)) {
    keep_cols      <- setdiff(names(tbl), drop_cols)
    tbl <- tbl[,keep_cols]
  }
  
  tbl_mat <- as.matrix(tbl)
  
  cosine_simils <- purrr::map_dbl(1:nrow(tbl_mat), ~cosine_simil(tbl_mat[.x,], vec))
  
  tbl_og[[out_col[1]]] <- cosine_simils
  tbl_og
}
