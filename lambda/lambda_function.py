import boto3

def lambda_handler(event, context):
    # Initialise the EC2 resource interface.
    ec2_resource = boto3.resource('ec2')
    released_count = 0

    # Iterate over all Elastic IPs in the VPC scope.
    for elastic_ip in ec2_resource.vpc_addresses.all():

        # Release the EIP if it's not associated with an instance.
        if elastic_ip.instance_id is None:
            try:
                print(f"Releasing unassociated EIP: {elastic_ip.public_ip} ({elastic_ip.allocation_id})")
                elastic_ip.release()
                released_count += 1
            except Exception as e:
                print(f"Error releasing EIP {elastic_ip.allocation_id}: {e}")

    return {
        'statusCode': 200,
        'body': f'Released {released_count} unassociated EIP(s).'
    }
