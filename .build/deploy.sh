#!/usr/bin/env bash
set -e

export TARGET=$1

init_gpg() {
    gpg2 --fast-import --no-tty --batch --yes smallrye-sign.asc
}

init_git() {
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global user.email "smallrye@googlegroups.com"

    git update-index --assume-unchanged .build/deploy.sh
    git update-index --assume-unchanged .build/decrypt-secrets.sh
}

deploy_snapshot() {
    echo "Deploying snapshot"
    mvn -B -fn clean
    mvn -B deploy -DskipTests -s maven-settings.xml
}

compatibility_extract() {
  echo "Extracting compatibility report"
  jbang .build/CompatibilityUtils.java extract
}

compatibility_clear() {
  echo "Clearing difference justifications"
  jbang .build/CompatibilityUtils.java clear
  git commit -a -m "[POST-RELEASE] - Clearing breaking change justifications"
  git push origin master
}

deploy_release() {
    export RELEASE_VERSION=""
    export BRANCH="HEAD"

    if [ -f /tmp/release-version ]; then
      RELEASE_VERSION=$(cat /tmp/release-version)
    else
        echo "'/tmp/release-version' required"
        exit 1
    fi

    echo "Cutting release ${RELEASE_VERSION}"
    mvn -B -fn clean
    git checkout ${BRANCH}
    HASH=$(git rev-parse --verify $BRANCH)
    echo "Last commit is ${HASH} - creating detached branch"
    git checkout -b "r${RELEASE_VERSION}" "${HASH}"

    echo "Update version to ${RELEASE_VERSION}"
    mvn -B versions:set -DnewVersion="${RELEASE_VERSION}" -DgenerateBackupPoms=false -s maven-settings.xml
    mvn -B clean verify -DskipTests -Prelease -s maven-settings.xml

    git commit -am "[RELEASE] - Bump version to ${RELEASE_VERSION}"
    git tag "${RELEASE_VERSION}"
    echo "Pushing tag to origin"
    git push origin "${RELEASE_VERSION}"

    echo "Deploying release artifacts"
    mvn -B clean deploy -DskipTests -Prelease -s maven-settings.xml

    echo "Deploying documentation"
    .build/deploy-site.sh
}

init_git
init_gpg

export EXTRA_ARGS=""
if [[ ${MICRO_RELEASE} == "true" ]]; then
  EXTRA_ARGS="--micro"
fi

if [[ ${TARGET} == "snapshot" ]]; then
    deploy_snapshot
elif [[ ${TARGET} == "release" ]]; then
    echo "Checking release prerequisites with ${EXTRA_ARGS}"
    .build/pre-release.kts "${GITHUB_TOKEN}" "${EXTRA_ARGS}"

    deploy_release

    echo "Executing post-release"
    compatibility_extract
    .build/post-release.kts "${GITHUB_TOKEN}"

    compatibility_clear
else
    echo "Unknown environment: ${TARGET}"
fi
