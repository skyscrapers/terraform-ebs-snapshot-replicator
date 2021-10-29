import boto3
import datetime
import json
import os

target_account_id = os.environ['TARGET_ACCOUNT_ID']
source_region = os.environ['SOURCE_REGION']
target_region = os.environ['TARGET_REGION']
match_tags = json.loads(os.environ['MATCH_TAGS'])
target_account_kms_key_arn = os.environ['TARGET_ACCOUNT_KMS_KEY_ARN']
setup_name = os.environ['SETUP_NAME']
retention_period = os.environ['RETENTION_PERIOD']


def match_ebs_snapshot(ec2, event):
    """Checks if the triggering snapshot event is to be processed"""

    snapshot = ec2.Snapshot(event['detail']['snapshot_id'].split("/")[-1])
    snapshot_tags = {}

    # Transfer tags into a dict so they are easier to compare
    for tag in snapshot.tags:
        snapshot_tags[tag['Key']] = tag['Value']

    if len(set(snapshot_tags.items()) & set(match_tags.items())) == len(set(match_tags.items())):
        return snapshot
    else:
        return False


def share_ebs_snapshot(event, context):
    """Lambda entry point for the share EBS snapshot function"""

    ec2 = boto3.resource('ec2')
    snapshot = match_ebs_snapshot(ec2, event)
    if snapshot:
        print('Sharing EBS snapshot ' + snapshot.id +
              ' with AWS account ' + target_account_id)
        snapshot.modify_attribute(
            Attribute='createVolumePermission',
            OperationType='add',
            UserIds=[target_account_id]
        )


def copy_ebs_snapshot(event, context):
    """Lambda entry point for the copy EBS snapshot function"""

    ec2 = boto3.resource('ec2', region_name=target_region)
    snapshot = match_ebs_snapshot(ec2, event)
    if snapshot:
        tags = snapshot.tags + [{
            'Key': 'created_by',
            'Value': setup_name
        }]
        print('Copying snapshot ID: ' + snapshot.id)
        snapshot.copy(
            Description=snapshot.description,
            SourceRegion=source_region,
            KmsKeyId=target_account_kms_key_arn,
            TagSpecifications=[{
                'ResourceType': 'snapshot',
                'Tags': tags
            }]
        )


def cleanup_ebs_snapshots(event, context):
    """Lambda entry point for the cleanup EBS snapshots function"""

    print('Lambda function start: going to clean up EBS snapshots older than ' +
          retention_period + ' days')

    ec2 = boto3.client('ec2', region_name=target_region)

    paginator = ec2.get_paginator('describe_snapshots')
    iterator = paginator.paginate(
        Filters=[
            {   # Get only the snapshots created by this setup
                'Name': 'tag:created_by',
                'Value': setup_name
            },
            {
                'Name': 'status',
                'Value': 'completed'
            }
        ],
        OwnerIds=['self']
    )

    for page in iterator:
        for snapshot in page['Snapshots']:
            create_ts = snapshot['StartTime'].replace(tzinfo=None)
            if create_ts < datetime.datetime.now() - datetime.timedelta(days=int(retention_period)):
                print('Cleaning up snapshot ' + snapshot['SnapshotId'])
                ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
