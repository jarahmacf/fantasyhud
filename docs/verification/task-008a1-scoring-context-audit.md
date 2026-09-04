# Task 008A.1 stored scoring-context audit

Status: **SEMANTIC-INTEGRITY CORRECTION AUDIT PASSED TRANSACTIONALLY — UNDEPLOYED DRAFT**

The initial read-only audit ran on 2026-09-01 against the 30 current Production league rows already stored in Supabase. It made no Sleeper request and performed no write.

The corrected migration was audited on 2026-09-04 in one hosted rollback-only transaction. The transaction applied the amended migration, ran the exact database test, exercised the same-time observation-conflict canary, collected aggregate evidence, and then rolled back. The migration remains undeployed on the draft Task 008A.1 branch; this document does not claim that these context tables or rows exist in Production.

This document contains aggregate findings only. It records no league ID, league name, app-user ID, fantasy-account ID, player ID, raw settings object, credential, or secret.

## Identity and size findings

The initial audit counted privacy-safe hashes over canonical PostgreSQL `jsonb` text and exact ordered roster-position arrays. The pre-correction complete-format audit hash combined exact scoring settings, exact ordered roster positions, team count, roster size, roster-management type, best-ball state, superflex state, and IDP state. Those hashes established distinct pre-implementation counts only; the amended migration's reviewed SHA-256 helpers define durable identity.

```text
current league count                         30
distinct exact scoring fingerprints          13
distinct exact roster-position fingerprints  14
distinct pre-correction format fingerprints  17

maximum scoring-settings size              2,591 bytes
maximum league-settings size               1,077 bytes
maximum roster-position count                 27
```

All stored exact objects and arrays are well below the migration's conservative bounds.

## Existing derived distributions

```text
broad scoring format  custom=24, ppr=6
team count             10=6, 12=21, 14=2, 32=1
best ball              false=3, true=27
roster management      dynasty=1, keeper=1, redraft=28
superflex              false=7, true=23
roster-derived IDP     false=30
base reception points  1=30
passing touchdowns     4=10, 5=4, 6=16
```

The existing broad `custom` count reconciles with the version-one rule: 24 leagues have at least one nonzero reviewed position-specific reception or premium value, while six do not.

## Scoring compatibility collision audit

The corrected hosted audit produced:

```text
exact scoring contexts                     13
semantic scoring compatibility keys        13
compatibility groups with >1 exact row       0
known material scoring differences grouped  0
```

Because no stored compatibility key contained more than one exact scoring fingerprint, there was no stored multi-exact group for which differing key categories, reviewed-no-op status, or unknown/malformed fallback needed to be reported. The exact pgTAP test separately verifies reviewed no-op equivalence and conservative unknown or malformed fallback.

The test exercised 12 explicit material-difference cases. None collapsed:

```text
rush_yd        rec_yd          pass_yd
rush_td        rec_td          pass_td
pass_int       first-down      kicking
team defense   IDP             nonzero bonus
```

Acceptance: **No compatibility group contains a known material scoring difference.**

### Exact values versus semantic no-ops

Exact scoring identity preserves every source key and exact source value, including zero-valued bonuses. The semantic projection removes a numeric-zero bonus only when its key is in this explicit version-one additive-no-op allowlist:

```text
bonus_def_fum_td_50p   bonus_def_int_td_50p
bonus_fd_qb            bonus_fd_rb
bonus_fd_te            bonus_fd_wr
bonus_pass_cmp_25      bonus_pass_yd_300
bonus_pass_yd_400      bonus_rec_rb
bonus_rec_te           bonus_rec_wr
bonus_rec_yd_100       bonus_rec_yd_200
bonus_rush_att_20      bonus_rush_rec_yd_100
bonus_rush_rec_yd_200  bonus_rush_td_qb
bonus_rush_yd_100      bonus_rush_yd_200
bonus_sack_2p          bonus_tkl_10p
```

This is an exact allowlist, not a `bonus_*` wildcard. The other reviewed no-op family is a numeric `rec_fb`, `rec_qb`, `rec_rb`, `rec_te`, or `rec_wr` value exactly equal to numeric base `rec`. Every other key/value, including a future bonus key or an unknown or malformed value, remains in the bounded effective object and therefore narrows compatibility.

## Position-specific reception and tight-end premium

Key presence and exact aggregate value distributions were:

```text
bonus_rec_rb  0=2, 0.25=1, 0.5=11, 1=1
bonus_rec_te  0=1, 0.5=9, 0.75=3, 1=12
bonus_rec_wr  0=2, 0.25=1, 0.5=1, 1=1
```

No `rec_fb`, `rec_qb`, `rec_rb`, `rec_te`, `rec_wr`, `bonus_rec_fb`, or `bonus_rec_qb` key was present. The reviewed version-one family still includes every one of those keys so a future valid source object is classified consistently.

For the stored rows, the safely derivable tight-end premium is the exact numeric `bonus_rec_te` value above. Position-specific reception key presence and nonzero materiality remain separate facts.

## Bonus-scoring categories

Twenty-four leagues contain at least one nonzero reviewed `bonus_*` value; six contain none. The stored bonus key union, with the number of leagues carrying each key, is:

```text
bonus_def_fum_td_50p=2   bonus_def_int_td_50p=2
bonus_fd_qb=2            bonus_fd_rb=2
bonus_fd_te=2            bonus_fd_wr=2
bonus_pass_cmp_25=2      bonus_pass_yd_300=2
bonus_pass_yd_400=2      bonus_rec_rb=15
bonus_rec_te=25          bonus_rec_wr=5
bonus_rec_yd_100=2       bonus_rec_yd_200=2
bonus_rush_att_20=2      bonus_rush_rec_yd_100=2
bonus_rush_rec_yd_200=2  bonus_rush_td_qb=2
bonus_rush_yd_100=2      bonus_rush_yd_200=2
bonus_sack_2p=2          bonus_tkl_10p=2
```

Exact identity preserves every source bonus value. The aggregate `has_bonus_scoring` field reports nonzero reviewed bonus scoring; key presence alone does not invent material scoring. Semantic compatibility removes only an explicitly allowlisted numeric-zero no-op as documented above.

## IDP-scoring categories

No current league has a nonzero reviewed individual-defense scoring value, and no exact roster-position array contains an IDP slot. Some settings objects still carry zero-valued IDP-capable keys. Their presence is retained for exact identity and bounded diagnostics without turning ordinary team-defense scoring into IDP scoring.

```text
explicit idp_* key presence:
  idp_blk_kick=1       idp_def_td=1
  idp_ff=1             idp_fum_rec=1
  idp_fum_ret_yd=1     idp_int=1
  idp_int_ret_yd=1     idp_pass_def=1
  idp_pass_def_3p=2    idp_qb_hit=1
  idp_sack=1           idp_sack_yd=2
  idp_safe=1           idp_tkl=1
  idp_tkl_ast=1        idp_tkl_loss=1
  idp_tkl_solo=1

reviewed unprefixed individual-defense key presence:
  qb_hit=2             tkl=2
  tkl_ast=2            tkl_loss=2
  tkl_solo=2
```

The reviewed family also permits exact `pass_def`; it was absent. Ordinary `def_*`, points-allowed, yards-allowed, special-teams, and team-defense turnover keys are not treated as individual-defense evidence.

## Unknown or unclassified categories

None of the stored scoring keys falls outside the reviewed version-one union. Future unknown or malformed keys remain preserved in exact settings and in the bounded semantic projection, appear by safe key name in bounded diagnostics, and narrow compatibility without invalidating exact identity.

## Sanitized scoring-key union

The union below contains provider scoring key names only and reveals no league or user identity. It is grouped for review; the grouping is not a replacement for exact stored settings.

### Bonus

```text
bonus_def_fum_td_50p bonus_def_int_td_50p
bonus_fd_qb bonus_fd_rb bonus_fd_te bonus_fd_wr
bonus_pass_cmp_25 bonus_pass_yd_300 bonus_pass_yd_400
bonus_rec_rb bonus_rec_te bonus_rec_wr
bonus_rec_yd_100 bonus_rec_yd_200
bonus_rush_att_20 bonus_rush_rec_yd_100 bonus_rush_rec_yd_200
bonus_rush_td_qb bonus_rush_yd_100 bonus_rush_yd_200
bonus_sack_2p bonus_tkl_10p
```

### Individual defense

```text
idp_blk_kick idp_def_td idp_ff idp_fum_rec idp_fum_ret_yd
idp_int idp_int_ret_yd idp_pass_def idp_pass_def_3p
idp_qb_hit idp_sack idp_sack_yd idp_safe
idp_tkl idp_tkl_ast idp_tkl_loss idp_tkl_solo
qb_hit tkl tkl_ast tkl_loss tkl_solo
```

### Passing, rushing, receiving, and fumbles

```text
pass_2pt pass_att pass_cmp pass_cmp_40p pass_fd pass_inc pass_int
pass_int_td pass_sack pass_td pass_td_40p pass_td_50p pass_yd
rush_2pt rush_40p rush_att rush_fd rush_td rush_td_40p
rush_td_50p rush_yd
rec rec_0_4 rec_5_9 rec_10_19 rec_20_29 rec_30_39 rec_40p
rec_2pt rec_fd rec_td rec_td_40p rec_td_50p rec_yd
fum fum_lost fum_rec fum_rec_td fum_ret_yd
```

### Kicking, team defense, and special teams

```text
blk_kick blk_kick_ret_yd
def_2pt def_3_and_out def_4_and_stop def_forced_punts
def_kr_yd def_pass_def def_pr_yd def_st_ff def_st_fum_rec
def_st_td def_st_tkl_solo def_td
ff int int_ret_yd sack sack_yd safe
fg_ret_yd fgm fgm_0_19 fgm_20_29 fgm_30_39 fgm_40_49
fgm_50_59 fgm_50p fgm_60p fgm_yds fgm_yds_over_30
fgmiss fgmiss_0_19 fgmiss_20_29 fgmiss_30_39 fgmiss_40_49
fgmiss_50_59 fgmiss_50p fgmiss_60p
kr_yd pr_yd st_ff st_fum_rec st_td st_tkl_solo xpm xpmiss
pts_allow pts_allow_0 pts_allow_1_6 pts_allow_7_13
pts_allow_14_20 pts_allow_21_27 pts_allow_28_34 pts_allow_35p
yds_allow yds_allow_0_100 yds_allow_100_199 yds_allow_200_299
yds_allow_300_349 yds_allow_350_399 yds_allow_400_449
yds_allow_450_499 yds_allow_500_549 yds_allow_550p
```

## Old exact-format collision audit

Under the pre-correction format grouping, three groups spanning 11 corrected exact format contexts contained more than one distinct exact league-settings fingerprint. That grouping could therefore have reused whichever exact settings object arrived first even though the source settings differed.

The corrected exact format fingerprint includes the provider-specific exact league-settings fingerprint. JSON object key reordering remains canonical, while any exact value difference produces different exact format identity.

## Corrected exact and compatible format audit

The rollback transaction produced these aggregate corrected-context results:

```text
current leagues                               30
distinct exact scoring contexts               13
distinct semantic scoring compatibility keys  13
distinct exact format contexts                 25
distinct lineup profiles                       14
distinct format compatibility keys             25
compatible groups with >1 exact format          0
known material format collision pairs           0

context quality  exact=25, partial=0, unknown=0
QB format        one_qb=6, superflex=18, two_qb=1
                 two_qb_superflex=0, no_qb=0, custom=0, unknown=0
IDP              false=25, true=0

current league pointers                        30
format observations                            30
```

Because no corrected compatibility key contained several exact format contexts, there was no stored multi-exact compatible group with differing dimensions to report. The exact pgTAP test separately verifies reviewed-compatible order-only lineup differences and rejects material scoring, slot-count, quarterback-format, IDP, team-count, best-ball, roster-management, and audited draft-relevant-setting differences.

Acceptance: **No compatibility group differs in known material scoring, lineup composition, QB format, IDP state, team count, best-ball state, roster-management state, or an audited draft-relevant league setting.**

## Hosted transactional verification and rollback

The exact hosted pgTAP plan completed all 167 assertions successfully. Coverage included full immutable-row validation, one-context-per-league-time idempotence, a contradictory same-time context failure, and rollback of the enclosing league mutation and current pointer.

```text
pgTAP assertions passed                         167
service_role direct CRUD grants on context data   0
current leagues with a format pointer             30
format observations                               30
```

Every post-rollback residue check returned zero or false. Production aggregates remained unchanged:

```text
fantasy accounts                  1
app-user account links            1
leagues                          30
account-league links             30
league users                    387
rosters                         372
roster players                7,196
players                      12,225
sync runs                         5
```

The successful canary proves the amended migration and test against hosted data without deploying either or leaving a schema or data mutation behind.

## Audit gate result

The stored Production state can be represented by the corrected version-one scoring and format classifiers without a provider request, broad-label substitution, identity leak, material compatibility collision, or unbounded source object. The hosted rollback-only correction audit passed, all current leagues received one context pointer and one initial observation inside the transaction, same-time contradiction failed with full rollback, and Production returned to its unchanged pre-audit state.

The correction remains an undeployed draft. Review, merge, Production migration deployment, and post-deployment verification are still required.
