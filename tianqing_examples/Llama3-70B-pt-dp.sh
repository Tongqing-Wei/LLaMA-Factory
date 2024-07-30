# You can observe that the number of steps for different stage is quite different. They are not magic number. They are set to those numbers simply because I esitimate the time it takes to finish the training, and 
# choose the number such that it fits my daily schedule>_<. This is for you to exactly reproduce my results. You many change the steps to other numbers if you want to.
MODEL_DIR=${MODEL_DIR:-"/mnt/zj-gpfs/home/lsy/models/Meta-Llama-3-8B"}
NGPUS=${NGPUS:-8}
WORLD_SIZE=${WORLD_SIZE:-1}
NUM_PROCESSES=$((${NGPUS}*${WORLD_SIZE}))
SEQ_LEN=${SEQ_LEN:-32768}
BATCH_SIZE=${BATCH_SIZE:-1}
ACC=${ACC:-4}
SAVE_PATH=${SAVE_PATH:-"./output/70B_32K_bs_1M_rope_1M_step_1000_lr_2e-5"}
SAVE_STEPS=${SAVE_STEPS:-500}
export PYTORCH_CUDA_ALLOC_CONF='max_split_size_mb:1024' 
export WANDB_DISABLED=true
export NCCL_DEBUG=WARN
echo ${RANK}/$[WORLD_SIZE]
if [ ${MASTER_ADDR} == 'localhost' ]; then
    export MASTER_ADDR=`hostname -i`
fi
echo ${MASTER_ADDR}:${MASTER_PORT}

accelerate launch \
--config_file examples/accelerate/ds_multi_nodes.yaml \
--use_deepspeed \
--num_machines ${WORLD_SIZE} \
--num_processes ${NUM_PROCESSES} \
--main_process_ip ${MASTER_ADDR} \
--main_process_port ${MASTER_PORT} \
--machine_rank ${RANK} \
--rdzv_conf "rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT,rdzv_backend=c10d" \
src/train.py \
--model_name_or_path ${MODEL_DIR} \
--stage pt \
--do_train \
--finetuning_type full \
--parallel_mode data_parallel \
--deepspeed examples/deepspeed/ds_z3_offload_config.json \
--tokenized_path /mnt/zj-gpfs/home/lsy/data/tokenized_c4_demo \
--template llama3 \
--cutoff_len ${SEQ_LEN} \
--max_samples 1000 \
--overwrite_cache \
--preprocessing_num_workers 16 \
--output_dir ${SAVE_PATH} \
--logging_steps 1 \
--save_steps ${SAVE_STEPS} \
--plot_loss \
--overwrite_output_dir \
--per_device_train_batch_size ${BATCH_SIZE} \
--gradient_accumulation_steps ${ACC} \
--learning_rate 2e-5 \
--num_train_epochs 3.0 \
--lr_scheduler_type cosine \
--warmup_ratio 0.1 \
--bf16 \
--ddp_timeout 180000000 \
--val_size 0.1 \
--eval_strategy steps \
--eval_steps 9999 \
--dataloader_drop_last
