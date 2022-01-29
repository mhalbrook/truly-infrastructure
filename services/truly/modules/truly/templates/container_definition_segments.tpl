{
  "dnsSearchDomains": null,
  "environmentFiles": null,
  "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
          "awslogs-group": "${ awslogs_group }",
          "awslogs-region": "${ aws_region }",
          "awslogs-stream-prefix": "ecs"
      }
  },
  "entryPoint": null,
  "portMappings": ${ port_mappings },
  "command": ${ command },
  "linuxParameters": null,
  "cpu": ${ cpu_units },
  "environment": ${ environment_variables },
  "resourceRequirements": null,
  "ulimits": ${ ulimits },
  "dnsServers": null,
  "mountPoints": ${ mount_points },
  "workingDirectory": null,
  "secrets": ${ secrets },
  "dockerSecurityOptions": null,
  "memory": ${ memory },
  "memoryReservation": ${ memory_reservation },
  "volumesFrom": ${ volumes_from },
  "stopTimeout": null,
  "image": "${ image }",
  "startTimeout": null,
  "firelensConfiguration": null,
  "dependsOn": ${ depends_on },
  "disableNetworking": null,
  "interactive": null,
  "healthCheck": ${ healthcheck },
  "essential": ${ essential },
  "links": null,
  "hostname": null,
  "extraHosts": null,
  "pseudoTerminal": null,
  "user": ${ user },
  "readonlyRootFilesystem": null,
  "dockerLabels": ${ docker_labels },
  "systemControls": null,
  "privileged": null,
  "name": "${ container_name }" 
},