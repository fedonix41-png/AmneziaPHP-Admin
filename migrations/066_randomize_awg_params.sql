-- Randomize AWG parameters for both awg2 and amnezia-wg-advanced protocols
UPDATE protocols
SET install_script = REPLACE(
    install_script,
    'JC=5
JMIN=50
JMAX=1000
S1_VAL=50
S2_VAL=100
S3_VAL=20
S4_VAL=10
H1_VAL=123456789
H2_VAL=223456789
H3_VAL=323456789
H4_VAL=423456789',
    'JC=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(3+rand()*(10-3+1))}'')
JMIN=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(10+rand()*(50-10+1))}'')
JMAX=$(awk -v seed=$RANDOM -v jmin=$JMIN ''BEGIN{srand(seed); print int(jmin+rand()*(1000-jmin+1))}'')
S1_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(15+rand()*(50-15+1))}'')
S2_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(110+rand()*(150-110+1))}'')
S3_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(110+rand()*(150-110+1))}'')
S4_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(5+rand()*(40-5+1))}'')
H1_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}'')
H2_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}'')
H3_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}'')
H4_VAL=$(awk -v seed=$RANDOM ''BEGIN{srand(seed); print int(100000000+rand()*(2000000000-100000000+1))}'')'
)
WHERE slug IN ('awg2', 'amnezia-wg-advanced');
